import Combine
import Foundation
import WatchConnectivity

/// Receives the iPhone's reward library over WatchConnectivity and persists it
/// in the App Group, so the picker keeps the last-synced library even when the
/// phone is unreachable. A sync is never required: without one, the built-in
/// catalog rules and the watch works fully standalone.
@MainActor
final class RewardLibraryStore: NSObject, ObservableObject {
    @Published private(set) var pickerRewards: [Reward] =
        RewardLibraryStore.loadLibrary()?.pickerRewards() ?? allRewards

    private static let libraryKey = "br.rewardLibrary"

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    static func loadLibrary() -> RewardLibrary? {
        let defaults = UserDefaults(suiteName: BurnRewardShared.appGroupID) ?? .standard
        guard let data = defaults.data(forKey: libraryKey) else { return nil }
        return RewardLibrary.decoded(from: data)
    }

    /// Full catalog including hidden built-ins — used when restoring an
    /// in-flight quest, whose reward must resolve even if it was hidden
    /// (or is a custom one) after the quest started.
    static func fullCatalog() -> [Reward] {
        loadLibrary()?.fullCatalog() ?? allRewards
    }

    private func apply(data: Data) {
        guard let library = RewardLibrary.decoded(from: data) else { return }
        let defaults = UserDefaults(suiteName: BurnRewardShared.appGroupID) ?? .standard
        defaults.set(data, forKey: Self.libraryKey)
        pickerRewards = library.pickerRewards()
    }

    nonisolated private func handle(context: [String: Any]) {
        guard let data = context[RewardLibrary.applicationContextKey] as? Data else { return }
        Task { @MainActor [weak self] in self?.apply(data: data) }
    }
}

extension RewardLibraryStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // The system caches the most recent context — apply it on every
        // activation so a library pushed while this app was closed still lands.
        handle(context: session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        handle(context: context)
    }
}
