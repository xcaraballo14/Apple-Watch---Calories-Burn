import Foundation
import WatchConnectivity

/// Pushes the reward library to the watch. The application context is
/// last-writer-wins and delivered by the system whenever the watch is next
/// reachable — exactly right for config: the newest library always lands,
/// and nothing is queued up or retried by hand.
@MainActor
final class WatchSyncService: NSObject {
    private var pendingLibrary: RewardLibrary?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(_ library: RewardLibrary) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingLibrary = library   // sent from activationDidComplete
            return
        }
        guard let data = library.encoded() else { return }
        try? session.updateApplicationContext([RewardLibrary.applicationContextKey: data])
    }
}

extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self, let pending = self.pendingLibrary else { return }
            self.pendingLibrary = nil
            self.push(pending)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Required for switching between paired watches.
        session.activate()
    }
}
