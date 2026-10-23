import AppKit
import Darwin
import Foundation
import os

enum ProcessManager {
    private static let logger = Logger(subsystem: "com.carloscosta.Janus", category: "ProcessManager")

    /// Get the actual argv array for a process using KERN_PROCARGS2 sysctl.
    /// This preserves argument boundaries (unlike `ps -o args=` which joins with spaces).
    static func getArgv(pid: Int) -> [String]? {
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
            var end = offset
            while end < size && buffer[end] != 0 { end += 1 }
            if let str = String(bytes: buffer[offset..<end], encoding: .utf8) {
                args.append(str)
            }
            offset = end + 1
        }
        return args.isEmpty ? nil : args
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
    struct ProcessIdentity: Equatable {
        let uid: uid_t
        let startSeconds: Int
        let startMicroseconds: Int32

        init?(pid: pid_t) {
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.stride
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
            guard pid > 0, sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
            uid = info.kp_eproc.e_ucred.cr_uid
            startSeconds = info.kp_proc.p_un.__p_starttime.tv_sec
            startMicroseconds = info.kp_proc.p_un.__p_starttime.tv_usec
        }
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

    /// A process we decided we may signal, plus (optionally) its group.
    private struct Target: Sendable {
        let pid: pid_t
        let pgid: pid_t?
        let identity: ProcessIdentity

        init?(pid rawPid: Int) {
            let pid = pid_t(rawPid)
            guard let identity = ProcessIdentity(pid: pid),
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

    /// SIGTERM the process (and its group when safe, e.g. npm + node, so the
    /// parent doesn't respawn the child), then SIGKILL after 3s if the *same*
    /// process is still alive.
    static func kill(pid: Int) {
        guard let target = Target(pid: pid) else {
            logger.warning("kill(pid:\(pid, privacy: .public)) refused - process gone or not owned by current user")
            return
        }
        target.send(SIGTERM)

        Task.detached {
            try? await Task.sleep(for: .seconds(3))
            if target.isStillRunning {
                target.send(SIGKILL)
            }
        }
    }

    static func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Kill the process (group) then relaunch the original command in the same cwd.
    /// Uses the captured argv so paths with spaces survive intact.
    static func restart(pid: Int) {
        guard let target = Target(pid: pid) else {
            logger.warning("restart(pid:\(pid, privacy: .public)) refused - process gone or not owned by current user")
            return
        }
        guard let argv = getArgv(pid: pid), !argv.isEmpty else {
            logger.warning("restart(pid:\(pid, privacy: .public)) - could not read argv")
            return
        }
        let workDir = getCwd(pid: pid)
        guard !workDir.isEmpty else {
            logger.warning("restart(pid:\(pid, privacy: .public)) - could not read cwd")
            return
        }

        target.send(SIGTERM)

        Task.detached {
            try? await Task.sleep(for: .seconds(2))
            if target.isStillRunning {
                target.send(SIGKILL)
            }
            try? await Task.sleep(for: .seconds(1))

            // Quote each argument individually so paths with spaces survive.
            let quotedArgs = argv.map { arg in
                "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
            }.joined(separator: " ")
            Shell.runDetached(quotedArgs, cwd: workDir)
        }
    }

    /// Open `path` in Warp if installed, otherwise Terminal.app.
    static func openTerminal(path: String) {
        let warpURL = URL(fileURLWithPath: "/Applications/Warp.app")
        let app = FileManager.default.fileExists(atPath: warpURL.path) ? "Warp" : "Terminal"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app, path]
        do {
            try process.run()
        } catch {
            logger.error("openTerminal failed for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
