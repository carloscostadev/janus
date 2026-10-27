import Foundation
import Observation

@Observable
@MainActor
final class PortScanner {
    var ports: [PortEntry] = []
    /// True when the last scan could not run `lsof`: the list shown is the
    /// last good one and may be out of date. Cleared by the next good scan.
    var lastScanFailed = false
    /// Show the processes in `systemProcesses` too (off by default). Saved in
    /// UserDefaults; changing it rescans right away.
    var showSystemProcesses: Bool {
        didSet {
            guard showSystemProcesses != oldValue else { return }
            defaults.set(showSystemProcesses, forKey: Self.showSystemProcessesKey)
            scan()
        }
    }
    @ObservationIgnored private let defaults: UserDefaults
    nonisolated static let showSystemProcessesKey = "showSystemProcesses"
    @ObservationIgnored private var timer: Timer?
    /// Guards against overlapping scans if one ever takes longer than the interval.
    @ObservationIgnored private var isScanning = false
    /// cwd -> project root. Only touched on the main actor; a snapshot is
    /// handed to the background scan and the pruned result stored back.
    @ObservationIgnored private var projectRootCache: [String: String] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showSystemProcesses = defaults.bool(forKey: Self.showSystemProcessesKey)
    }

    /// Processes whose listening ports we always want hidden - system services
    /// and noisy desktop apps that aren't relevant to dev work.
    /// (Note: `lsof` truncates COMMAND to 9 chars by default, so these match
    /// the truncated names.)
    nonisolated static let systemProcesses: Set<String> = [
        "ControlCe", "rapportd", "stable", "figma_age", "GitHub", "Spotify", "Cursor", "AnyDesk",
        "IPNExtens",  // Tailscale network extension
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
                projectRoot: ""  // not resolved yet - see scan()
            ))
        }

        return entries
    }

    // MARK: - Scan (runs off the main thread)

    struct ScanResult {
        let ports: [PortEntry]
        let projectRootCache: [String: String]
    }

    nonisolated static func runLsof() -> String? {
        Shell.run("/usr/sbin/lsof", ["-iTCP", "-sTCP:LISTEN", "-P", "-n"])
    }

    /// One full scan: a single `lsof` for listening sockets (exec'd directly,
    /// no shell), cwds read natively, project roots served from `rootCache`
    /// when the cwd was already resolved. Returns `nil` when `lsof` could not
    /// run, so the caller keeps the last known list instead of blanking it.
    /// `lsof` is injectable for tests.
    nonisolated static func performScan(rootCache: [String: String], includeSystem: Bool = false,
                                        lsof: () -> String? = runLsof) -> ScanResult? {
        guard let output = lsof() else { return nil }
        let rawEntries = parseLsofOutput(output)
            .filter { includeSystem || !systemProcesses.contains($0.processName) }

        var cache: [String: String] = [:]
        var enriched: [PortEntry] = []
        enriched.reserveCapacity(rawEntries.count)
        for entry in rawEntries {
            let cwd = ProcessManager.getCwd(pid: entry.pid)
            let isSystemPath = cwd.isEmpty || cwd == "/" || cwd.hasPrefix("/private/")
            let resolvedPath = isSystemPath ? entry.processName : cwd
            let root = cache[resolvedPath] ?? rootCache[resolvedPath] ?? PortEntry.resolveProjectRoot(for: resolvedPath)
            cache[resolvedPath] = root
            enriched.append(PortEntry(
                pid: entry.pid,
                port: entry.port,
                projectPath: resolvedPath,
                processName: entry.processName,
                projectRoot: root,
                identity: ProcessManager.ProcessIdentity(pid: pid_t(entry.pid))
            ))
        }

        // `cache` only keeps paths seen in this scan, so it can't grow unbounded.
        return ScanResult(ports: enriched.sorted { $0.port < $1.port }, projectRootCache: cache)
    }

    /// Trigger a refresh. The actual work runs on a background task so the
    /// menu bar UI never blocks. Final assignment happens on the main actor,
    /// and only when something changed (avoids needless SwiftUI invalidation
    /// of the menu bar label every 3s).
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        let rootCache = projectRootCache
        let includeSystem = showSystemProcesses

        Task.detached(priority: .utility) { [weak self] in
            let result = PortScanner.performScan(rootCache: rootCache, includeSystem: includeSystem)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isScanning = false
                self.apply(result)
            }
        }
    }

    /// Store a scan result. `nil` (lsof could not run) keeps the last list and
    /// flags it as possibly stale instead of blanking it.
    func apply(_ result: ScanResult?) {
        guard let result else {
            if !lastScanFailed { lastScanFailed = true }
            return
        }
        if lastScanFailed { lastScanFailed = false }
        projectRootCache = result.projectRootCache
        if ports != result.ports {
            ports = result.ports
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
        // Let the system coalesce wakeups with other timers (energy impact).
        timer?.tolerance = interval * 0.2
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
