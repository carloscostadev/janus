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

@Test func killTerminatesOwnChildProcess() async throws {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/bin/sleep")
    child.arguments = ["30"]
    try child.run()
    ProcessManager.kill(pid: Int(child.processIdentifier))
    for _ in 0..<50 where child.isRunning {
        try await Task.sleep(for: .milliseconds(100))
    }
    #expect(!child.isRunning)
    #expect(child.terminationReason == .uncaughtSignal)
}

@Test func killRefusesLaunchd() {
    // Must be a no-op (logged), never a signal to pid 1 or to group -1.
    ProcessManager.kill(pid: 1)
    #expect(ProcessManager.ProcessIdentity(pid: 1) != nil)
}
