import Darwin
import Foundation
import Testing
@testable import Janus

/// Restarts real dev servers, each launched the way a developer would (own
/// process group, like a terminal tab), and checks that the port listens
/// again under a new PID. Opt-in, because it spawns servers on local ports:
/// `JANUS_RESTART_E2E=1 swift test --filter RestartE2ETests`
/// Needs python3, node and npm on PATH. Results are printed for the README.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["JANUS_RESTART_E2E"] != nil), .serialized)
struct RestartE2ETests {
    /// Launch `command` in `dir` through `perl -e setpgrp` so it gets its own
    /// process group, then wait until something listens on `port`.
    static func launch(_ command: [String], in dir: URL, port: Int) async throws -> (Process, Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", "setpgrp(0, 0); exec @ARGV or die", "--"] + command
        process.currentDirectoryURL = dir
        var env = ProcessInfo.processInfo.environment
        env["PORT"] = String(port)
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        for _ in 0..<100 {
            if let pid = ProcessManager.listeningPIDs(port: port).first { return (process, pid) }
            try await Task.sleep(for: .milliseconds(100))
        }
        process.terminate()
        throw CancellationError()
    }

    static func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("janus-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Restart whatever listens on `port`, print the outcome, clean up.
    static func restartAndCheck(_ name: String, port: Int, command: [String], in dir: URL) async throws {
        let (launcher, pid) = try await launch(command, in: dir, port: port)
        let argv = ProcessManager.getArgv(pid: pid) ?? []
        let result = await ProcessManager.restart(pid: pid, port: port)
        let newPIDs = ProcessManager.listeningPIDs(port: port)
        print("E2E \(name): listener PID \(pid) argv \(argv.map { URL(fileURLWithPath: $0).lastPathComponent }) -> \(result); now listening: \(newPIDs)")
        for newPID in newPIDs { kill(pid_t(newPID), SIGTERM) }
        launcher.terminate()
        try? FileManager.default.removeItem(at: dir)
        guard case let .restarted(newPID) = result else {
            Issue.record("\(name): expected a restart, got \(result)")
            return
        }
        #expect(newPID != pid)
    }

    @Test func pythonHTTPServer() async throws {
        let port = 47_311
        try await Self.restartAndCheck("python3 -m http.server", port: port,
                                       command: ["python3", "-m", "http.server", String(port), "--bind", "127.0.0.1"],
                                       in: Self.tempDir())
    }

    @Test func nodeDirect() async throws {
        let dir = try Self.tempDir()
        try "require('http').createServer((q, s) => s.end('ok')).listen(process.env.PORT, '127.0.0.1')"
            .write(to: dir.appendingPathComponent("server.js"), atomically: true, encoding: .utf8)
        try await Self.restartAndCheck("node server.js", port: 47_312, command: ["node", "server.js"], in: dir)
    }

    @Test func npmRunDev() async throws {
        // npm -> sh -> node: the listener is node, a grandchild of npm.
        let dir = try Self.tempDir()
        try "require('http').createServer((q, s) => s.end('ok')).listen(process.env.PORT, '127.0.0.1')"
            .write(to: dir.appendingPathComponent("server.js"), atomically: true, encoding: .utf8)
        try #"{"name":"janus-e2e","private":true,"scripts":{"dev":"node server.js"}}"#
            .write(to: dir.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try await Self.restartAndCheck("npm run dev", port: 47_313, command: ["npm", "run", "dev"], in: dir)
    }

    @Test func shellScriptWithChild() async throws {
        // A wrapper script whose child (python) holds the port.
        let dir = try Self.tempDir()
        let script = dir.appendingPathComponent("serve.sh")
        try "#!/bin/sh\npython3 -m http.server \"$PORT\" --bind 127.0.0.1\n"
            .write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        try await Self.restartAndCheck("./serve.sh (child python)", port: 47_314, command: ["./serve.sh"], in: dir)
    }
}
