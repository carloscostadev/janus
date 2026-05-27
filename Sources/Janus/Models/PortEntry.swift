import Foundation

struct PortEntry: Identifiable, Equatable, Hashable {
    let pid: Int
    let port: Int
    let projectPath: String
    let processName: String
    /// Pre-computed at scan time so SwiftUI re-renders don't hit the filesystem.
    let projectRoot: String

    /// Designated init: callers that already resolved `projectRoot` pass it in
    /// to avoid duplicate filesystem walks. If omitted, we resolve once here.
    init(pid: Int, port: Int, projectPath: String, processName: String, projectRoot: String? = nil) {
        self.pid = pid
        self.port = port
        self.projectPath = projectPath
        self.processName = processName
        self.projectRoot = projectRoot ?? Self.resolveProjectRoot(for: projectPath)
    }

    var id: String { "\(pid)-\(port)" }

    /// Last path component of `projectRoot` — cheap, no I/O.
    var projectName: String { (projectRoot as NSString).lastPathComponent }

    /// Display-friendly path with `~` substitution. Pure string work, no I/O.
    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path()
        let homePath = home.hasSuffix("/") ? String(home.dropLast()) : home
        if projectPath.hasPrefix(homePath) {
            return "~" + projectPath.dropFirst(homePath.count)
        }
        return projectPath
    }

    /// Walks up from `path` looking for common project marker files (.git,
    /// package.json, Gemfile, composer.json, go.mod). Falls back to the first
    /// non-container directory under home.
    ///
    /// This is *the* expensive operation in this struct — it does multiple
    /// `FileManager.fileExists` calls — so it MUST only be invoked at scan
    /// time, not from inside computed properties used in view bodies.
    static func resolveProjectRoot(for path: String) -> String {
        let markers = [".git", "package.json", "Gemfile", "composer.json", "go.mod"]
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path()
        let homePath = home.hasSuffix("/") ? String(home.dropLast()) : home

        // Only attempt resolution for paths under home
        guard path.hasPrefix(homePath) else { return path }

        var current = path
        while current.count > homePath.count {
            for marker in markers {
                if fm.fileExists(atPath: current + "/" + marker) {
                    return current
                }
            }
            current = (current as NSString).deletingLastPathComponent
        }

        // Fallback: first non-container directory under home
        let containers: Set<String> = ["Documents", "Desktop", "Projects", "Developer", "Downloads"]
        let relative = String(path.dropFirst(homePath.count + 1))
        let components = relative.split(separator: "/").map(String.init)

        var depth = 0
        for component in components {
            depth += 1
            if !containers.contains(component) {
                let rootComponents = [homePath] + components.prefix(depth)
                return rootComponents.joined(separator: "/")
            }
        }

        return path
    }
}
