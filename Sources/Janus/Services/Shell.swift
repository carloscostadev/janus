import Foundation
import os

/// Tiny wrapper around `Process` for running shell commands and capturing stdout.
/// Centralising this avoids the previous duplication between PortScanner and
/// ProcessManager and gives us one place to add logging / sandboxing later.
enum Shell {
    private static let logger = Logger(subsystem: "com.carloscosta.Janus", category: "Shell")

    /// Run `command` through `/bin/zsh -c` and return stdout (UTF-8).
    /// Errors are logged via `os_log` and surface as an empty string so callers
    /// can keep working without try/catch noise.
    @discardableResult
    static func run(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Shell.run failed to spawn /bin/zsh -c \(command, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return ""
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Fire-and-forget: spawn a detached login shell to run `command` in `cwd`.
    /// Used for restarting user processes — they must outlive Janus.
    static func runDetached(_ command: String, cwd: String) {
        let escapedCwd = cwd.replacingOccurrences(of: "'", with: "'\\''")
        let wrapped = "cd '\(escapedCwd)' && nohup \(command) > /dev/null 2>&1 &"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", wrapped]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("Shell.runDetached failed in \(cwd, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        process.waitUntilExit()
    }
}
