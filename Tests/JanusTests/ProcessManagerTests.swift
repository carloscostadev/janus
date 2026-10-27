import Darwin
import Foundation
import Testing
@testable import Janus

@Test func refusesToSignalGroupOneOrBelow() {
    // kill(-1, sig) would signal every process of the user.
    #expect(!ProcessManager.shouldSignalGroup(pgid: 1, ownGroup: 500, leaderUID: 501, currentUID: 501, leaderIsAppBundle: false))
    #expect(!ProcessManager.shouldSignalGroup(pgid: 0, ownGroup: 500, leaderUID: 501, currentUID: 501, leaderIsAppBundle: false))
    #expect(!ProcessManager.shouldSignalGroup(pgid: -1, ownGroup: 500, leaderUID: 501, currentUID: 501, leaderIsAppBundle: false))
}

@Test func refusesOwnOtherUserAndAppBundleGroups() {
    #expect(!ProcessManager.shouldSignalGroup(pgid: 500, ownGroup: 500, leaderUID: 501, currentUID: 501, leaderIsAppBundle: false))
    #expect(!ProcessManager.shouldSignalGroup(pgid: 700, ownGroup: 500, leaderUID: 0, currentUID: 501, leaderIsAppBundle: false))
    #expect(!ProcessManager.shouldSignalGroup(pgid: 700, ownGroup: 500, leaderUID: nil, currentUID: 501, leaderIsAppBundle: false))
    #expect(!ProcessManager.shouldSignalGroup(pgid: 700, ownGroup: 500, leaderUID: 501, currentUID: 501, leaderIsAppBundle: true))
    #expect(ProcessManager.shouldSignalGroup(pgid: 700, ownGroup: 500, leaderUID: 501, currentUID: 501, leaderIsAppBundle: false))
}

@Test func refusesLaunchdSelfAndOtherUsersProcesses() {
    #expect(!ProcessManager.canSignal(pid: 1, ownPID: 42, ownerUID: 501, currentUID: 501))
    #expect(!ProcessManager.canSignal(pid: 42, ownPID: 42, ownerUID: 501, currentUID: 501))
    #expect(!ProcessManager.canSignal(pid: 900, ownPID: 42, ownerUID: 0, currentUID: 501))
    #expect(!ProcessManager.canSignal(pid: 900, ownPID: 42, ownerUID: nil, currentUID: 501))
    #expect(ProcessManager.canSignal(pid: 900, ownPID: 42, ownerUID: 501, currentUID: 501))
}

@Test func processIdentityOfLiveAndMissingProcess() {
    let me = ProcessManager.ProcessIdentity(pid: getpid())
    #expect(me != nil)
    #expect(me?.uid == getuid())
    #expect(me == ProcessManager.ProcessIdentity(pid: getpid()))
    #expect(ProcessManager.ProcessIdentity(pid: 0) == nil)
    #expect(ProcessManager.ProcessIdentity(pid: 99_999_999) == nil)
}

@Test func getCwdReadsCurrentProcessDirectoryNatively() {
    let expected = FileManager.default.currentDirectoryPath
    let cwd = ProcessManager.getCwd(pid: Int(getpid()))
    #expect(URL(fileURLWithPath: cwd).resolvingSymlinksInPath().path == URL(fileURLWithPath: expected).resolvingSymlinksInPath().path)
    #expect(ProcessManager.getCwd(pid: 99_999_999) == "")
}

/// A child that sleeps for `seconds` (a unique value, so a relaunched copy
/// can be found and cleaned up).
private func spawnSleeper(_ seconds: String = "30") throws -> Process {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/bin/sleep")
    child.arguments = [seconds]
    try child.run()
    return child
}

@Test func stopTerminatesOwnChildProcess() async throws {
    let child = try spawnSleeper()
    let result = await ProcessManager.stop(pid: Int(child.processIdentifier), port: 1, listeners: { _ in [] })
    #expect(result == .stopped)
    for _ in 0..<20 where child.isRunning {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(!child.isRunning)
    #expect(child.terminationReason == .uncaughtSignal)
}

@Test func stopRefusesLaunchd() async {
    // Must never signal pid 1 or group -1.
    #expect(await ProcessManager.stop(pid: 1, port: 1, listeners: { _ in [] }) == .refused)
    #expect(ProcessManager.ProcessIdentity(pid: 1) != nil)
}

@Test func stopRefusesAnotherUsersProcess() async throws {
    // Any root-owned process other than launchd (e.g. syslogd, logd).
    let output = try #require(Shell.run("/bin/ps", ["-U", "0", "-o", "pid="]))
    let rootPID = try #require(output.split(whereSeparator: \.isNewline).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.first { $0 > 1 })
    let before = ProcessManager.ProcessIdentity(pid: pid_t(rootPID))
    #expect(await ProcessManager.stop(pid: rootPID, port: 1, listeners: { _ in [] }) == .refused)
    #expect(await ProcessManager.restart(pid: rootPID, port: 1, listeners: { _ in [] }) == .refused)
    #expect(ProcessManager.ProcessIdentity(pid: pid_t(rootPID)) == before)
}

@Test func stopRefusesReusedPID() async throws {
    // The scan saw another process under this PID (different start time):
    // the live one must be left alone.
    let child = try spawnSleeper()
    defer { child.terminate() }
    let live = try #require(ProcessManager.ProcessIdentity(pid: child.processIdentifier))
    let scanned = ProcessManager.ProcessIdentity(uid: live.uid, startSeconds: live.startSeconds - 60,
                                                 startMicroseconds: live.startMicroseconds)
    let pid = Int(child.processIdentifier)
    #expect(await ProcessManager.stop(pid: pid, port: 1, expected: scanned, listeners: { _ in [] }) == .refused)
    #expect(await ProcessManager.restart(pid: pid, port: 1, expected: scanned, listeners: { _ in [] }) == .refused)
    #expect(child.isRunning)
    // With the identity the scan really captured, the stop goes through.
    #expect(await ProcessManager.stop(pid: pid, port: 1, expected: live, listeners: { _ in [] }) == .stopped)
}

@Test func isSameProcessComparesScanAndLiveIdentity() {
    let a = ProcessManager.ProcessIdentity(uid: 501, startSeconds: 100, startMicroseconds: 1)
    let b = ProcessManager.ProcessIdentity(uid: 501, startSeconds: 200, startMicroseconds: 1)
    #expect(ProcessManager.isSameProcess(current: a, expected: a))
    #expect(ProcessManager.isSameProcess(current: a, expected: nil))
    #expect(!ProcessManager.isSameProcess(current: a, expected: b))
    #expect(!ProcessManager.isSameProcess(current: nil, expected: a))
}

@Test func stopReportsAlreadyGoneProcess() async {
    #expect(await ProcessManager.stop(pid: 99_999_999, port: 1, listeners: { _ in [] }) == .alreadyGone)
    #expect(await ProcessManager.restart(pid: 99_999_999, port: 1, listeners: { _ in [] }) == .alreadyGone)
}

@Test func stopReportsPortTakenByAnotherProcess() async throws {
    let child = try spawnSleeper()
    let result = await ProcessManager.stop(pid: Int(child.processIdentifier), port: 4321, listeners: { _ in [77777] })
    #expect(result == .portTaken(pid: 77777))
}

@Test func restartRelaunchesSameCommandAndReportsWhenNotListening() async throws {
    // A unique duration identifies the relaunched copy for cleanup.
    let marker = "41.\(Int.random(in: 100...999))"
    let child = try spawnSleeper(marker)
    let result = await ProcessManager.restart(pid: Int(child.processIdentifier), port: 1,
                                              listenTimeout: .milliseconds(300), listeners: { _ in [] })
    #expect(result == .relaunchedNotListening)
    #expect(!child.isRunning)
    // The same argv runs again, detached.
    let found = Shell.run("/usr/bin/pgrep", ["-f", "sleep \(marker)"]) ?? ""
    let relaunched = found.split(whereSeparator: \.isNewline).compactMap { Int($0) }
    #expect(!relaunched.isEmpty)
    for pid in relaunched { kill(pid_t(pid), SIGKILL) }
}

@Test func restartReportsNewListener() async throws {
    let marker = "42.\(Int.random(in: 100...999))"
    let child = try spawnSleeper(marker)
    let result = await ProcessManager.restart(pid: Int(child.processIdentifier), port: 1,
                                              listenTimeout: .seconds(2), listeners: { _ in [55555] })
    #expect(result == .restarted(pid: 55555))
    let found = Shell.run("/usr/bin/pgrep", ["-f", "sleep \(marker)"]) ?? ""
    for pid in found.split(whereSeparator: \.isNewline).compactMap({ Int($0) }) { kill(pid_t(pid), SIGKILL) }
}

@Test func listeningPIDsOfFreePortIsEmpty() {
    #expect(ProcessManager.listeningPIDs(port: 1).isEmpty)
}

@Test func readsArgvAndEnvironmentOfOwnProcess() throws {
    // macOS hides the environment of Apple platform binaries (/bin/sleep), not
    // of the user's own tools (node, python): use an ad-hoc signed copy.
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("janus-env-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let sleeper = dir.appendingPathComponent("sleeper")
    try FileManager.default.copyItem(atPath: "/bin/sleep", toPath: sleeper.path)
    #expect(Shell.run("/usr/bin/codesign", ["-f", "-s", "-", sleeper.path]) != nil)

    let child = Process()
    child.executableURL = sleeper
    child.arguments = ["30"]
    child.environment = ["JANUS_TEST_ENV": "port 4000", "PATH": "/usr/bin:/bin"]
    try child.run()
    defer { child.terminate() }
    let pid = Int(child.processIdentifier)
    #expect(ProcessManager.getArgv(pid: pid) == [sleeper.path, "30"])
    let env = try #require(ProcessManager.getEnvironment(pid: pid))
    #expect(env["JANUS_TEST_ENV"] == "port 4000")
    #expect(ProcessManager.getEnvironment(pid: 1) == nil)
}
