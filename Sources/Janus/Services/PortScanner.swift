import Foundation
import Observation

@Observable
@MainActor
final class PortScanner {
    var ports: [PortEntry] = []
    @ObservationIgnored private var timer: Timer?

    /// Processes whose listening ports we always want hidden — system services
    /// and noisy desktop apps that aren't relevant to dev work.
    /// (Note: `lsof` truncates COMMAND to 9 chars by default, so these match
    /// the truncated names.)
    nonisolated static let systemProcesses: Set<String> = [
        "ControlCe", "rapportd", "stable", "figma_age", "GitHub", "Spotify", "Cursor", "AnyDesk",
    ]

    // MARK: - Parsing helpers (pure, testable, isolation-free)

    nonisolated static func parsePort(from name: String) -> Int? {
        guard let colonIndex = name.lastIndex(of: ":") else { return nil }
        let portString = name[name.index(after: colonIndex)...]
        return Int(portString)
    }

    nonisolated static func parseLsofOutput(_ output: String) -> [PortEntry] {
        let lines = output.components(separatedBy: "\n")
        var seen = Set<Int>()
        var entries: [PortEntry] = []

        for line in lines.dropFirst() {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 10 else { continue }

            let processName = String(columns[0])
            guard let pid = Int(columns[1]) else { continue }

            let name = String(columns[columns.count - 2])
            guard let port = parsePort(from: name) else { continue }
            guard seen.insert(port).inserted else { continue }

            entries.append(PortEntry(
                pid: pid,
                port: port,
                projectPath: "",
                processName: processName,
                projectRoot: ""  // not resolved yet — see scan()
            ))
        }

        return entries
    }

    /// Parse the `-Fn` output of `lsof -a -p PID1,PID2,... -d cwd` into a
    /// `[pid: cwd]` map. The output alternates `p<pid>` and `n<path>` lines.
    nonisolated static func parseCwdOutput(_ output: String) -> [Int: String] {
        var result: [Int: String] = [:]
        var currentPid: Int?
        for line in output.components(separatedBy: "\n") {
            guard let first = line.first else { continue }
            let rest = String(line.dropFirst())
            switch first {
            case "p":
                currentPid = Int(rest)
            case "n":
                if let pid = currentPid, !rest.isEmpty {
                    result[pid] = rest
                }
            default:
                break
            }
        }
        return result
    }

    // MARK: - Shell glue (called off the main thread by scan())

    nonisolated static func resolveCwds(for pids: [Int]) -> [Int: String] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.map(String.init).joined(separator: ",")
        // ONE lsof call for all PIDs instead of N — was previously the main
        // CPU hog when many dev servers were running.
        let output = Shell.run("lsof -a -p \(pidList) -d cwd -Fn 2>/dev/null")
        return parseCwdOutput(output)
    }

    // MARK: - Scan + polling

    /// Trigger a refresh. The actual work (shelling out to `lsof`, resolving
    /// project roots) runs on a background task so the menu bar UI never
    /// blocks. Final assignment happens on the main actor.
    func scan() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let output = Shell.run("lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null")
            let rawEntries = PortScanner.parseLsofOutput(output)

            // Batch resolve cwds in a single shell out.
            let pids = rawEntries.map { $0.pid }
            let cwds = PortScanner.resolveCwds(for: pids)

            // Build the final entries with project paths + roots resolved once.
            var enriched: [PortEntry] = []
            enriched.reserveCapacity(rawEntries.count)
            for entry in rawEntries {
                let cwd = cwds[entry.pid] ?? ""
                let isSystemPath = cwd.isEmpty || cwd == "/" || cwd.hasPrefix("/private/")
                let resolvedPath = isSystemPath ? entry.processName : cwd
                enriched.append(PortEntry(
                    pid: entry.pid,
                    port: entry.port,
                    projectPath: resolvedPath,
                    processName: entry.processName
                    // projectRoot computed inside the init — once, here, off main.
                ))
            }

            let filtered = enriched
                .filter { !PortScanner.systemProcesses.contains($0.processName) }
                .sorted { $0.port < $1.port }

            await MainActor.run { [weak self] in
                self?.ports = filtered
            }
        }
    }

    func startPolling(interval: TimeInterval = 3.0) {
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Timer fires on the main RunLoop; bridge to the actor explicitly so
            // strict concurrency stays happy.
            Task { @MainActor in
                self?.scan()
            }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
