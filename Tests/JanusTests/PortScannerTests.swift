import Testing
@testable import Janus

@Test func parseLsofOutput() {
    let output = """
    COMMAND     PID        USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    node      10796 carloscosta   16u  IPv6 0xada48ba84b971838      0t0  TCP [::1]:5173 (LISTEN)
    node      26974 carloscosta   16u  IPv6 0xd1a59e60060473ba      0t0  TCP *:3000 (LISTEN)
    nginx     32632 carloscosta    5u  IPv4 0x3d5cb5a24dfe4e79      0t0  TCP 127.0.0.1:10018 (LISTEN)
    """
    let parsed = PortScanner.parseLsofOutput(output)
    #expect(parsed.count == 3)
    #expect(parsed[0].pid == 10796)
    #expect(parsed[0].port == 5173)
    #expect(parsed[0].processName == "node")
    #expect(parsed[1].port == 3000)
    #expect(parsed[2].port == 10018)
    #expect(parsed[2].processName == "nginx")
}

@Test func parseLsofOutputDeduplicatesPids() {
    let output = """
    COMMAND     PID        USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    ControlCe   649 carloscosta   10u  IPv4  0xc86c176be83108c      0t0  TCP *:7000 (LISTEN)
    ControlCe   649 carloscosta   11u  IPv6 0x47e05f14a2cdfa6d      0t0  TCP *:7000 (LISTEN)
    """
    let parsed = PortScanner.parseLsofOutput(output)
    #expect(parsed.count == 1)
    #expect(parsed[0].port == 7000)
}

@Test func parseLsofOutputEmpty() {
    let parsed = PortScanner.parseLsofOutput("")
    #expect(parsed.isEmpty)
}

@Test func parsePortFromName() {
    #expect(PortScanner.parsePort(from: "*:3000") == 3000)
    #expect(PortScanner.parsePort(from: "127.0.0.1:8080") == 8080)
    #expect(PortScanner.parsePort(from: "[::1]:5173") == 5173)
    #expect(PortScanner.parsePort(from: "invalid") == nil)
}
