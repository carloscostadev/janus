import Foundation

struct PortEntry: Identifiable, Equatable, Hashable {
    let pid: Int
    let port: Int
    let projectPath: String
    let processName: String

    var id: String { "\(pid)-\(port)" }

    var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path()
        let homePath = home.hasSuffix("/") ? String(home.dropLast()) : home
        if projectPath.hasPrefix(homePath) {
            return "~" + projectPath.dropFirst(homePath.count)
        }
        return projectPath
    }

    /// Resolves the project root by walking up from `projectPath` looking for
    /// common project marker files (.git, package.json, Gemfile, etc.).
    /// Falls back to the first non-container directory under home.
    var projectRoot: String {
        let markers = [".git", "package.json", "Gemfile", "composer.json", "go.mod"]
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path()
        let homePath = home.hasSuffix("/") ? String(home.dropLast()) : home

        // Only attempt resolution for paths under home
        guard projectPath.hasPrefix(homePath) else { return projectPath }

        var current = projectPath
        var deepestRoot: String?

        // Walk up from projectPath towards home looking for marker files
        while current.count > homePath.count {
            for marker in markers {
                let candidate = current + "/" + marker
                if fm.fileExists(atPath: candidate) {
                    deepestRoot = current
                }
            }
            if deepestRoot != nil { break }
            current = (current as NSString).deletingLastPathComponent
        }

        if let root = deepestRoot {
            return root
        }

        // Fallback: first non-container directory under home
        let containers: Set<String> = ["Documents", "Desktop", "Projects", "Developer", "Downloads"]
        let relative = String(projectPath.dropFirst(homePath.count + 1)) // remove ~/
        let components = relative.split(separator: "/").map(String.init)

        var depth = 0
        for component in components {
            depth += 1
            if !containers.contains(component) {
                let rootComponents = [homePath] + components.prefix(depth)
                return rootComponents.joined(separator: "/")
            }
        }

        return projectPath
    }

    /// The display name for the project (last path component of projectRoot).
    var projectName: String {
        (projectRoot as NSString).lastPathComponent
    }
}
