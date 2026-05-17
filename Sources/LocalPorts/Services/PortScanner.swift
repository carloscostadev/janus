import Foundation
import Observation

@Observable
final class PortScanner {
    var ports: [PortEntry] = []
    private var timer: Timer?

    static func parsePort(from name: String) -> Int? {
        guard let colonIndex = name.lastIndex(of: ":") else { return nil }
        let portString = name[name.index(after: colonIndex)...]
        return Int(portString)
    }

    static func parseLsofOutput(_ output: String) -> [PortEntry] {
        let lines = output.components(separatedBy: "\n")
        var seen = Set<String>()
        var entries: [PortEntry] = []

        for line in lines.dropFirst() {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 10 else { continue }

            let processName = String(columns[0])
            guard let pid = Int(columns[1]) else { continue }

            let name = String(columns[columns.count - 2])
            guard let port = parsePort(from: name) else { continue }

            let key = "\(port)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            entries.append(PortEntry(
                pid: pid,
                port: port,
                projectPath: "",
                processName: processName
            ))
        }

        return entries
    }

    static func runShell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func resolveProjectPath(pid: Int) -> String {
        // Use lsof -a to AND the filters (get cwd for this specific PID)
        let output = runShell("lsof -a -p \(pid) -d cwd -Fn 2>/dev/null | grep '^n/' | head -1")
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("n") {
            return String(path.dropFirst())
        }
        return ""
    }

    func scan() {
        let output = Self.runShell("lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null")
        var entries = Self.parseLsofOutput(output)

        for i in entries.indices {
            let path = Self.resolveProjectPath(pid: entries[i].pid)
            let isSystemPath = path.isEmpty || path == "/" || path.hasPrefix("/private/")
            entries[i] = PortEntry(
                pid: entries[i].pid,
                port: entries[i].port,
                projectPath: isSystemPath ? entries[i].processName : path,
                processName: entries[i].processName
            )
        }

        let systemProcesses: Set<String> = ["ControlCe", "rapportd", "stable", "figma_age", "GitHub", "Spotify", "Cursor", "AnyDesk"]
        entries = entries.filter { entry in
            !systemProcesses.contains(entry.processName)
        }

        entries.sort { $0.port < $1.port }
        self.ports = entries
    }

    func startPolling(interval: TimeInterval = 3.0) {
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
