import Foundation
import Testing
@testable import Janus

@Test func portEntryCreation() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path()
    let homeClean = home.hasSuffix("/") ? String(home.dropLast()) : home
    let entry = PortEntry(
        pid: 1234,
        port: 3000,
        projectPath: "\(homeClean)/projects/my-app",
        processName: "node"
    )
    #expect(entry.pid == 1234)
    #expect(entry.port == 3000)
    #expect(entry.projectPath == "\(homeClean)/projects/my-app")
    #expect(entry.processName == "node")
    #expect(entry.displayPath == "~/projects/my-app")
}

@Test func portEntryDisplayPathWithTilde() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path()
    let homeClean = home.hasSuffix("/") ? String(home.dropLast()) : home
    let entry = PortEntry(
        pid: 1,
        port: 8080,
        projectPath: "\(homeClean)/Documents/project",
        processName: "python"
    )
    #expect(entry.displayPath == "~/Documents/project")
}

@Test func portEntryDisplayPathNoHome() {
    let entry = PortEntry(
        pid: 1,
        port: 8080,
        projectPath: "/opt/server",
        processName: "nginx"
    )
    #expect(entry.displayPath == "/opt/server")
}

@Test func portEntryEquality() {
    let a = PortEntry(pid: 100, port: 3000, projectPath: "/a", processName: "node")
    let b = PortEntry(pid: 100, port: 3000, projectPath: "/a", processName: "node")
    #expect(a == b)
}
