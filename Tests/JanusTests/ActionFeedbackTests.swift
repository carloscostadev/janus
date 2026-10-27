import Testing
@testable import Janus

@Test func stopResultsMapToTone() {
    #expect(ActionFeedback.forStop(.stopped, port: 3000).tone == .success)
    #expect(ActionFeedback.forStop(.alreadyGone, port: 3000).tone == .success)
    #expect(ActionFeedback.forStop(.portTaken(pid: 9), port: 3000).tone == .failure)
    #expect(ActionFeedback.forStop(.refused, port: 3000).tone == .failure)
    #expect(ActionFeedback.forStop(.stillRunning, port: 3000).tone == .failure)
    #expect(ActionFeedback.forStop(.stopped, port: 3000).text.contains(":3000"))
    #expect(ActionFeedback.forStop(.portTaken(pid: 4242), port: 3000).text.contains("4242"))
}

@Test func restartResultsMapToTone() {
    #expect(ActionFeedback.forRestart(.restarted(pid: 77), port: 5173).tone == .success)
    #expect(ActionFeedback.forRestart(.restarted(pid: 77), port: 5173).text.contains("77"))
    for failure: ProcessManager.ActionResult in [.relaunchedNotListening, .refused, .alreadyGone, .cannotRestart, .relaunchFailed, .stillRunning] {
        #expect(ActionFeedback.forRestart(failure, port: 5173).tone == .failure)
    }
}

@Test func stopAllSummary() {
    #expect(ActionFeedback.forStopAll(ended: 3, total: 3).tone == .success)
    #expect(ActionFeedback.forStopAll(ended: 2, total: 3).tone == .failure)
    #expect(ActionFeedback.processEnded(.portTaken(pid: 1)))
    #expect(!ActionFeedback.processEnded(.refused))
}
