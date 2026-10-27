import AppKit
import Darwin
import Foundation
import os

enum ProcessManager {
    private static let logger = Logger(subsystem: "com.carloscosta.Janus", category: "ProcessManager")

    /// Get the actual argv array for a process using KERN_PROCARGS2 sysctl.
    /// This preserves argument boundaries (unlike `ps -o args=` which joins with spaces).
    static func getArgv(pid: Int) -> [String]? {
        procArgs(pid: pid)?.argv
    }

    /// Environment of a process (KERN_PROCARGS2 lists it after argv). Only
    /// readable for the current user's own processes.
    static func getEnvironment(pid: Int) -> [String: String]? {
        guard let env = procArgs(pid: pid)?.env, !env.isEmpty else { return nil }
        var result: [String: String] = [:]
        for entry in env {
            guard let eq = entry.firstIndex(of: "="), eq != entry.startIndex else { continue }
            result[String(entry[..<eq])] = String(entry[entry.index(after: eq)...])
        }
        return result.isEmpty ? nil : result
    }

    /// argv and the raw `KEY=value` environment strings of a process.
    private static func procArgs(pid: Int) -> (argv: [String], env: [String])? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, Int32(pid)]
        var size: Int = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        // First 4 bytes: argc (int32)
        let argc: Int32 = buffer.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
        }

        var offset = MemoryLayout<Int32>.size
        // Skip exec_path (null-terminated)
        while offset < size && buffer[offset] != 0 { offset += 1 }
        // Skip null padding after exec_path
        while offset < size && buffer[offset] == 0 { offset += 1 }

        // Read argc null-terminated strings
        var args: [String] = []
        for _ in 0..<argc {
            guard offset < size else { break }
            var end = offset
            while end < size && buffer[end] != 0 { end += 1 }
            if let str = String(bytes: buffer[offset..<end], encoding: .utf8) {
                args.append(str)
            }
            offset = end + 1
        }
        guard !args.isEmpty else { return nil }

        // Then the environment, until an empty string or the end of the buffer.
        var env: [String] = []
        while offset < size && buffer[offset] != 0 {
            var end = offset
            while end < size && buffer[end] != 0 { end += 1 }
            if let str = String(bytes: buffer[offset..<end], encoding: .utf8) {
                env.append(str)
            }
            offset = end + 1
        }
        return (args, env)
    }

    /// Current working directory of a process, read natively via
    /// `proc_pidinfo(PROC_PIDVNODEPATHINFO)`: no `lsof` fork, ~microseconds.
    /// Single source of truth for PortScanner and restart(). Returns "" when
    /// the process is gone or belongs to another user.
    static func getCwd(pid: Int) -> String {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(Int32(pid), PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return "" }
        return withUnsafePointer(to: &info.pvi_cdir.vip_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
    }

    // MARK: - Signalling (safety checks)

    /// Owner + start time of a live process. Comparing two snapshots tells us
    /// whether a PID still refers to the *same* process (PIDs get reused).
    /// A zombie (exited, not yet reaped) has no identity: it can't be signalled
    /// and must count as gone.
    struct ProcessIdentity: Equatable, Hashable, Sendable {
        let uid: uid_t
        let startSeconds: Int
        let startMicroseconds: Int32

        init(uid: uid_t, startSeconds: Int, startMicroseconds: Int32) {
            self.uid = uid
            self.startSeconds = startSeconds
            self.startMicroseconds = startMicroseconds
        }

        init?(pid: pid_t) {
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.stride
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
            guard pid > 0, sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0,
                  info.kp_proc.p_stat != SZOMB else { return nil }
            uid = info.kp_eproc.e_ucred.cr_uid
            startSeconds = info.kp_proc.p_un.__p_starttime.tv_sec
            startMicroseconds = info.kp_proc.p_un.__p_starttime.tv_usec
        }
    }

    /// What a stop or restart ended in, shown to the user after the click.
    enum ActionResult: Equatable, Sendable {
        /// The process is gone and the port is free.
        case stopped
        /// The command runs again and listens on the port (new PID).
        case restarted(pid: Int)
        /// The command was relaunched, but nothing listens on the port yet.
        case relaunchedNotListening
        /// Janus may not signal it: another user's or a system process, or the
        /// PID now belongs to a different process than the one listed.
        case refused
        /// The process was already gone before the click took effect.
        case alreadyGone
        /// Still alive after SIGKILL.
        case stillRunning
        /// The process is gone, but another process listens on the port.
        case portTaken(pid: Int)
        /// argv or cwd could not be read, so the command can't be relaunched.
        case cannotRestart
        /// The relaunch shell could not be spawned.
        case relaunchFailed
    }

    /// Whether signalling the whole process group (`kill(-pgid)`) is safe.
    /// Refuses pgid <= 1 (`kill(-1)` would hit every process of the user),
    /// Janus's own group, groups owned by someone else, and groups led by a
    /// `.app` bundle (e.g. a dev server spawned by an editor shares the
    /// editor's group; killing the group would close the editor).
    static func shouldSignalGroup(pgid: pid_t, ownGroup: pid_t, leaderUID: uid_t?, currentUID: uid_t, leaderIsAppBundle: Bool) -> Bool {
        pgid > 1 && pgid != ownGroup && leaderUID == currentUID && !leaderIsAppBundle
    }

    /// Whether Janus may signal `pid` at all: a real user process, not
    /// launchd, not Janus itself, owned by the current user.
    static func canSignal(pid: pid_t, ownPID: pid_t, ownerUID: uid_t?, currentUID: uid_t) -> Bool {
        pid > 1 && pid != ownPID && ownerUID == currentUID
    }

    private static func executablePath(pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return "" }
        return String(cString: buffer)
    }

    /// Whether the process behind `pid` right now is the one the scan saw.
    /// `expected == nil` (identity not captured) accepts the live process.
    static func isSameProcess(current: ProcessIdentity?, expected: ProcessIdentity?) -> Bool {
        guard let current else { return false }
        return expected == nil || current == expected
    }

    /// A process we decided we may signal, plus (optionally) its group.
    private struct Target: Sendable {
        let pid: pid_t
        let pgid: pid_t?
        let identity: ProcessIdentity

        /// `expected` is the identity captured at scan time: if the PID was
        /// reused in between, the live process is a different one and is
        /// left alone.
        init?(pid rawPid: Int, expected: ProcessIdentity? = nil) {
            let pid = pid_t(rawPid)
            guard let identity = ProcessIdentity(pid: pid),
                  ProcessManager.isSameProcess(current: identity, expected: expected),
                  ProcessManager.canSignal(pid: pid, ownPID: getpid(), ownerUID: identity.uid, currentUID: getuid())
            else { return nil }
            self.pid = pid
            self.identity = identity

            let pgid = getpgid(pid)
            let safeGroup = ProcessManager.shouldSignalGroup(
                pgid: pgid,
                ownGroup: getpgrp(),
                leaderUID: ProcessIdentity(pid: pgid)?.uid,
                currentUID: getuid(),
                leaderIsAppBundle: ProcessManager.executablePath(pid: pgid).contains(".app/Contents/MacOS/")
            )
            self.pgid = safeGroup ? pgid : nil
        }

        func send(_ signal: Int32) {
            if let pgid { Foundation.kill(-pgid, signal) }
            Foundation.kill(pid, signal)
        }

        /// True while `pid` still refers to the process we captured.
        var isStillRunning: Bool { ProcessIdentity(pid: pid) == identity }
    }

    /// PIDs listening on TCP `port` right now (`lsof -t`); empty when the port is free.
    static func listeningPIDs(port: Int) -> [Int] {
        guard let output = Shell.run("/usr/sbin/lsof", ["-t", "-iTCP:\(port)", "-sTCP:LISTEN", "-P", "-n"]) else { return [] }
        return output.split(whereSeparator: \.isNewline).compactMap { Int($0) }
    }

    /// Polls `condition` every 100 ms until it holds or `timeout` passes.
    private static func waitUntil(_ timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    /// SIGTERM, then SIGKILL after `grace` if the *same* process is still alive.
    /// Returns false only when it survived SIGKILL too.
    private static func terminate(_ target: Target, grace: Duration) async -> Bool {
        target.send(SIGTERM)
        if await waitUntil(grace, { !target.isStillRunning }) { return true }
        target.send(SIGKILL)
        return await waitUntil(.seconds(1), { !target.isStillRunning })
    }

    /// Stop the process (and its group when safe, e.g. npm + node, so the
    /// parent doesn't respawn the child): SIGTERM, SIGKILL after 3 s if the
    /// same process is still alive, then check who holds the port.
    /// `expected` is the identity captured at scan time (PID reuse guard).
    static func stop(pid: Int, port: Int, expected: ProcessIdentity? = nil,
                     listeners: (Int) -> [Int] = listeningPIDs) async -> ActionResult {
        guard ProcessIdentity(pid: pid_t(pid)) != nil else { return .alreadyGone }
        guard let target = Target(pid: pid, expected: expected) else {
            logger.warning("stop(pid:\(pid, privacy: .public)) refused - not owned by current user or PID reused")
            return .refused
        }
        guard await terminate(target, grace: .seconds(3)) else { return .stillRunning }
        if let other = listeners(port).first(where: { $0 != pid }) { return .portTaken(pid: other) }
        return .stopped
    }

    static func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Stop the process (group) like `stop`, but with a 2 s grace, then
    /// relaunch the original argv in the same cwd, with the process's own
    /// environment (e.g. PORT), and wait up to `listenTimeout` for something
    /// to listen on `port` again. Not reproduced: the TTY, the parent process
    /// (npm, a wrapper script) and its output, which goes to /dev/null.
    static func restart(pid: Int, port: Int, expected: ProcessIdentity? = nil,
                        listenTimeout: Duration = .seconds(15),
                        listeners: (Int) -> [Int] = listeningPIDs) async -> ActionResult {
        guard ProcessIdentity(pid: pid_t(pid)) != nil else { return .alreadyGone }
        guard let target = Target(pid: pid, expected: expected) else {
            logger.warning("restart(pid:\(pid, privacy: .public)) refused - not owned by current user or PID reused")
            return .refused
        }
        guard let argv = getArgv(pid: pid), !argv.isEmpty else {
            logger.warning("restart(pid:\(pid, privacy: .public)) - could not read argv")
            return .cannotRestart
        }
        let workDir = getCwd(pid: pid)
        guard !workDir.isEmpty else {
            logger.warning("restart(pid:\(pid, privacy: .public)) - could not read cwd")
            return .cannotRestart
        }
        let environment = getEnvironment(pid: pid)

        guard await terminate(target, grace: .seconds(2)) else { return .stillRunning }
        // Give the kernel a moment to release the port before relaunching.
        try? await Task.sleep(for: .seconds(1))

        // Quote each argument individually so paths with spaces survive.
        let quotedArgs = argv.map { arg in
            "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
        }.joined(separator: " ")
        guard Shell.runDetached(quotedArgs, cwd: workDir, environment: environment) else { return .relaunchFailed }

        var newPID: Int?
        _ = await waitUntil(listenTimeout) {
            newPID = listeners(port).first(where: { $0 != pid })
            return newPID != nil
        }
        return newPID.map { .restarted(pid: $0) } ?? .relaunchedNotListening
    }

    /// Open `path` in Warp if installed, otherwise Terminal.app. Returns false
    /// when `open` could not run or reported an error.
    @discardableResult
    static func openTerminal(path: String) -> Bool {
        let warpURL = URL(fileURLWithPath: "/Applications/Warp.app")
        let app = FileManager.default.fileExists(atPath: warpURL.path) ? "Warp" : "Terminal"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app, path]
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            logger.error("openTerminal failed for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
