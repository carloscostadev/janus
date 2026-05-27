import AppKit
import Darwin
import Foundation

enum ProcessManager {
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

    static func kill(pid: Int) {
        let pid32 = Int32(pid)
        let pgid = getpgid(pid32)
        // Kill the entire process group (e.g. npm + node) so the parent
        // doesn't respawn the child. Fall back to individual PID.
        if pgid > 0 {
            Foundation.kill(-pgid, SIGTERM)
        }
        Foundation.kill(pid32, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if Foundation.kill(pid32, 0) == 0 {
                if pgid > 0 {
                    Foundation.kill(-pgid, SIGKILL)
                }
                Foundation.kill(pid32, SIGKILL)
            }
        }
    }

    static func openInBrowser(port: Int) {
        guard let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func getCwd(pid: Int) -> String {
        let output = PortScanner.runShell("lsof -a -p \(pid) -d cwd -Fn 2>/dev/null | grep '^n/' | head -1")
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("n") {
            return String(path.dropFirst())
        }
        return ""
    }

    static func getCommand(pid: Int) -> (command: String, workDir: String)? {
        let args = PortScanner.runShell("ps -o args= -p \(pid)").trimmingCharacters(in: .whitespacesAndNewlines)
        if args.isEmpty { return nil }
        let dir = getCwd(pid: pid)
        return (args, dir)
    }

    static func restart(pid: Int) {
        // Get argv as a proper array (preserves spaces in paths)
        guard let argv = getArgv(pid: pid), !argv.isEmpty else { return }
        let workDir = getCwd(pid: pid)
        guard !workDir.isEmpty else { return }

        let pid32 = Int32(pid)
        let pgid = getpgid(pid32)
        if pgid > 0 {
            Foundation.kill(-pgid, SIGTERM)
        }
        Foundation.kill(pid32, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if Foundation.kill(pid32, 0) == 0 {
                if pgid > 0 {
                    Foundation.kill(-pgid, SIGKILL)
                }
                Foundation.kill(pid32, SIGKILL)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                let escapedDir = workDir.replacingOccurrences(of: "'", with: "'\\''")
                // Quote each argument individually so paths with spaces are preserved
                let quotedArgs = argv.map { arg in
                    "'\(arg.replacingOccurrences(of: "'", with: "'\\''"))'"
                }.joined(separator: " ")
                let shellCommand = "cd '\(escapedDir)' && nohup \(quotedArgs) > /dev/null 2>&1 &"

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", shellCommand]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try? process.run()
                process.waitUntilExit()
            }
        }
    }

    static func openTerminal(path: String) {
        let warpURL = URL(fileURLWithPath: "/Applications/Warp.app")
        let app = FileManager.default.fileExists(atPath: warpURL.path) ? "Warp" : "Terminal"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app, path]
        try? process.run()
    }
}
