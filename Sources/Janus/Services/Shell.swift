import Foundation
import os

/// Tiny wrapper around `Process` for running commands and capturing stdout.
/// Centralising this avoids the previous duplication between PortScanner and
/// ProcessManager and gives us one place to add logging / sandboxing later.
enum Shell {
    private static let logger = Logger(subsystem: "com.carloscosta.Janus", category: "Shell")

    /// Exec `executable` directly (no intermediate shell, so no quoting issues
    /// and one fork less per call) and return its stdout (UTF-8).
    ///
    /// Returns `nil` only when the process could not be spawned, so callers can
    /// tell "command failed" apart from "command ran and printed nothing".
    /// stdout is drained *before* waiting for exit: waiting first deadlocks as
    /// soon as the output exceeds the pipe buffer (64 KB).
    static func run(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Shell.run failed to spawn \(executable, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    /// Fire-and-forget: spawn a detached shell to run `command` in `cwd`.
    /// Used for restarting user processes - they must outlive Janus. With
    /// `environment` (the original process's), the command runs with exactly
    /// that environment; without it, a login shell rebuilds the user's PATH.
    /// Returns false when the shell could not be spawned or enter `cwd`.
    @discardableResult
    static func runDetached(_ command: String, cwd: String, environment: [String: String]? = nil) -> Bool {
        let escapedCwd = cwd.replacingOccurrences(of: "'", with: "'\\''")
        let wrapped = "cd '\(escapedCwd)' && nohup \(command) > /dev/null 2>&1 &"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        if let environment {
            process.environment = environment
            process.arguments = ["-f", "-c", wrapped]
        } else {
            process.arguments = ["-l", "-c", wrapped]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Shell.runDetached failed in \(cwd, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
