import Foundation
import Testing
@testable import Janus

@Test func parseLsofOutput() {
    let output = """
    COMMAND     PID        USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    node      10796 carloscosta   16u  IPv6 0xada48ba84b971838      0t0  TCP [::1]:5173 (LISTEN)
    node      26974 carloscosta   16u  IPv6 0xd1a59e60060473ba      0t0  TCP *:3000 (LISTEN)
    nginx     32632 carloscosta    5u  IPv4 0x3d5cb5a24dfe4e79      0t0  TCP 127.0.0.1:10018 (LISTEN)
    """
    let parsed = PortScanner.parseLsofOutput(output)
    #expect(parsed.count == 3)
    #expect(parsed[0].pid == 10796)
    #expect(parsed[0].port == 5173)
    #expect(parsed[0].processName == "node")
    #expect(parsed[1].port == 3000)
    #expect(parsed[2].port == 10018)
    #expect(parsed[2].processName == "nginx")
}

@Test func parseLsofOutputDeduplicatesPids() {
    let output = """
    COMMAND     PID        USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    ControlCe   649 carloscosta   10u  IPv4  0xc86c176be83108c      0t0  TCP *:7000 (LISTEN)
    ControlCe   649 carloscosta   11u  IPv6 0x47e05f14a2cdfa6d      0t0  TCP *:7000 (LISTEN)
    """
    let parsed = PortScanner.parseLsofOutput(output)
    #expect(parsed.count == 1)
    #expect(parsed[0].port == 7000)
}

@Test func parseLsofOutputEmpty() {
    let parsed = PortScanner.parseLsofOutput("")
    #expect(parsed.isEmpty)
}

@Test func parsePortFromName() {
    #expect(PortScanner.parsePort(from: "*:3000") == 3000)
    #expect(PortScanner.parsePort(from: "127.0.0.1:8080") == 8080)
    #expect(PortScanner.parsePort(from: "[::1]:5173") == 5173)
    #expect(PortScanner.parsePort(from: "invalid") == nil)
}

@Test func shellRunReturnsNilWhenExecutableMissing() {
    #expect(Shell.run("/nonexistent/janus-test-binary", []) == nil)
    #expect(Shell.run("/bin/echo", ["ok"]) == "ok\n")
}

@Test func shellRunDrainsOutputLargerThanPipeBuffer() {
    // Waiting for exit before reading deadlocked once stdout exceeded 64 KB.
    let output = Shell.run("/bin/sh", ["-c", "head -c 300000 /dev/zero | tr '\\\\0' 'x'"])
    #expect(output?.count == 300_000)
}

@Test func noiseFilterIncludesKnownDesktopServices() {
    for name in ["ControlCe", "rapportd", "Spotify", "Cursor", "AnyDesk", "IPNExtens"] {
        #expect(PortScanner.systemProcesses.contains(name))
    }
    #expect(!PortScanner.systemProcesses.contains("node"))
}

@Test func performScanReusesProjectRootCache() {
    // A sentinel root proves cached roots are reused instead of re-walking
    // the filesystem; only paths seen in this scan survive in the new cache.
    guard let first = PortScanner.performScan(rootCache: [:]) else {
        Issue.record("lsof could not run")
        return
    }
    let seeded = Dictionary(uniqueKeysWithValues: Set(first.ports.map(\.projectPath)).map { ($0, "/sentinel/\($0.count)") })
    guard let second = PortScanner.performScan(rootCache: seeded.merging(["/stale/path": "/stale"]) { a, _ in a }) else {
        Issue.record("lsof could not run")
        return
    }
    #expect(second.projectRootCache["/stale/path"] == nil)
    for entry in second.ports where seeded[entry.projectPath] != nil {
        #expect(entry.projectRoot == seeded[entry.projectPath])
    }
}

private let sampleWithNoise = """
COMMAND     PID        USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
ControlCe   649 someone   10u  IPv4  0xc86c176be83108c      0t0  TCP *:7000 (LISTEN)
node      26974 someone   16u  IPv6 0xd1a59e60060473ba      0t0  TCP *:3000 (LISTEN)
"""

@Test func performScanReturnsNilWhenLsofCannotRun() {
    #expect(PortScanner.performScan(rootCache: [:], lsof: { nil }) == nil)
}

@Test func performScanHidesSystemProcessesUnlessAsked() throws {
    let hidden = try #require(PortScanner.performScan(rootCache: [:], lsof: { sampleWithNoise }))
    #expect(hidden.ports.map(\.port) == [3000])
    let shown = try #require(PortScanner.performScan(rootCache: [:], includeSystem: true, lsof: { sampleWithNoise }))
    #expect(shown.ports.map(\.port) == [3000, 7000])
}

@MainActor
@Test func failedScanKeepsLastListAndFlagsIt() {
    let scanner = PortScanner(defaults: UserDefaults(suiteName: "JanusScannerTests-\(UUID().uuidString)")!)
    let good = PortScanner.performScan(rootCache: [:], lsof: { sampleWithNoise })
    scanner.apply(good)
    #expect(scanner.ports.map(\.port) == [3000])
    #expect(!scanner.lastScanFailed)

    scanner.apply(nil)
    #expect(scanner.lastScanFailed)
    #expect(scanner.ports.map(\.port) == [3000])

    scanner.apply(good)
    #expect(!scanner.lastScanFailed)
}

@MainActor
@Test func showSystemProcessesIsSavedAndOffByDefault() {
    let suite = "JanusScannerTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    let scanner = PortScanner(defaults: defaults)
    #expect(!scanner.showSystemProcesses)
    scanner.showSystemProcesses = true
    #expect(defaults.bool(forKey: PortScanner.showSystemProcessesKey))
    #expect(PortScanner(defaults: defaults).showSystemProcesses)
    defaults.removePersistentDomain(forName: suite)
}

@Test func scanCapturesProcessIdentity() throws {
    // Entries carry the identity seen at scan time (PID reuse guard).
    let result = try #require(PortScanner.performScan(rootCache: [:]))
    for entry in result.ports where ProcessManager.ProcessIdentity(pid: pid_t(entry.pid)) != nil {
        #expect(entry.identity != nil)
    }
}
