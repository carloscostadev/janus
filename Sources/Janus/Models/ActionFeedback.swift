import Foundation

/// One status line shown in the popover while an action runs and for a few
/// seconds after it ends, so a click never looks like it did nothing.
struct ActionFeedback: Equatable {
    enum Tone: Equatable { case working, success, failure }

    let text: String
    let tone: Tone

    static func working(_ text: String) -> Self { Self(text: text, tone: .working) }
    static func success(_ text: String) -> Self { Self(text: text, tone: .success) }
    static func failure(_ text: String) -> Self { Self(text: text, tone: .failure) }

    /// Result of stopping the process listening on `port`.
    static func forStop(_ result: ProcessManager.ActionResult, port: Int) -> Self {
        switch result {
        case .stopped, .restarted, .relaunchedNotListening:
            return .success(L(":%d · Stopped, port free", port))
        case .alreadyGone:
            return .success(L(":%d · Already stopped", port))
        case let .portTaken(pid):
            return .failure(L(":%d · Stopped, but PID %d listens on it now", port, pid))
        case .refused:
            return .failure(L(":%d · Not stopped: process changed or not yours", port))
        case .stillRunning:
            return .failure(L(":%d · Still running after SIGKILL", port))
        case .cannotRestart, .relaunchFailed:
            return .failure(L(":%d · Not stopped", port))
        }
    }

    /// Result of restarting the process listening on `port`.
    static func forRestart(_ result: ProcessManager.ActionResult, port: Int) -> Self {
        switch result {
        case let .restarted(pid):
            return .success(L(":%d · Restarted (PID %d)", port, pid))
        case .relaunchedNotListening:
            return .failure(L(":%d · Relaunched, not listening yet", port))
        case .alreadyGone:
            return .failure(L(":%d · Not restarted: process already gone", port))
        case .refused:
            return .failure(L(":%d · Not restarted: process changed or not yours", port))
        case .cannotRestart:
            return .failure(L(":%d · Not restarted: command or folder unreadable", port))
        case .relaunchFailed:
            return .failure(L(":%d · Stopped, but the command did not relaunch", port))
        case .stillRunning:
            return .failure(L(":%d · Still running after SIGKILL", port))
        case .stopped, .portTaken:
            return .failure(L(":%d · Stopped, but the command did not relaunch", port))
        }
    }

    /// Whether a stop result means the process is no longer running.
    static func processEnded(_ result: ProcessManager.ActionResult) -> Bool {
        switch result {
        case .stopped, .alreadyGone, .portTaken: return true
        default: return false
        }
    }

    /// Summary of "Stop all": `ended` of `total` processes no longer run.
    static func forStopAll(ended: Int, total: Int) -> Self {
        ended == total
            ? .success(L("Stopped %d processes", total))
            : .failure(L("Stopped %d of %d processes", ended, total))
    }
}
