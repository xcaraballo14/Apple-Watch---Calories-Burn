import Foundation

/// The user's reward customization — custom rewards plus visibility for the
/// built-ins. Owned and edited on the iPhone, mirrored to the watch over the
/// WatchConnectivity application context (last-writer-wins, delivered whenever
/// the watch is next reachable). If nothing has ever synced, the built-in
/// catalog stands alone, so the watch stays fully standalone-capable.
///
/// Reward names are the identity (`Reward.id == name`) — the watch persists
/// selections by name across launches — so names must be unique; the iPhone
/// editor enforces that before a custom reward can be saved.
struct RewardLibrary: Codable, Equatable {
    var schemaVersion: Int = 1
    /// User-created rewards, in display order (shown before the built-ins).
    var customRewards: [Reward] = []
    /// Names of built-in rewards hidden from the watch picker.
    var hiddenBuiltInNames: Set<String> = []

    nonisolated static let applicationContextKey = "com.burnreward.rewardLibrary"

    /// Picker order: your creations first, then the visible built-ins.
    func pickerRewards(builtIns: [Reward] = allRewards) -> [Reward] {
        customRewards + builtIns.filter { !hiddenBuiltInNames.contains($0.name) }
    }

    /// Everything, including hidden built-ins — used to restore an in-flight
    /// quest whose reward may have been hidden since it started.
    func fullCatalog(builtIns: [Reward] = allRewards) -> [Reward] {
        customRewards + builtIns
    }

    func encoded() -> Data? { try? JSONEncoder().encode(self) }

    static func decoded(from data: Data) -> RewardLibrary? {
        try? JSONDecoder().decode(RewardLibrary.self, from: data)
    }
}
