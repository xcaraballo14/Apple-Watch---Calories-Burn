import Foundation

/// Lightweight snapshot of the current goal, shared from the Watch app to the
/// complication via an App Group. The widget process can't read WorkoutManager's
/// in-memory state, so the app writes this on every change and asks WidgetKit to reload.
struct BurnRewardSnapshot: Codable, Hashable {
    var isActive: Bool      // true while a workout is in progress
    var emoji: String       // primary reward emoji
    var caloriesBurned: Int
    var totalGoal: Int

    var progress: Double {
        guard totalGoal > 0 else { return 0 }
        return min(Double(caloriesBurned) / Double(totalGoal), 1.0)
    }

    var caloriesLeft: Int { max(totalGoal - caloriesBurned, 0) }

    /// Shown before any goal is set, and in widget galleries / previews.
    static let placeholder = BurnRewardSnapshot(
        isActive: false, emoji: "🔥", caloriesBurned: 0, totalGoal: 0
    )

    /// A filled-in sample so the complication preview looks alive.
    static let sample = BurnRewardSnapshot(
        isActive: true, emoji: "🍕", caloriesBurned: 240, totalGoal: 400
    )
}

enum BurnRewardShared {
    /// Must match the App Group enabled on BOTH the Watch app and the widget target.
    static let appGroupID = "group.com.burnreward.app"

    private static let snapshotKey = "br.widgetSnapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func save(_ snapshot: BurnRewardSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func load() -> BurnRewardSnapshot {
        guard
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(BurnRewardSnapshot.self, from: data)
        else { return .placeholder }
        return snapshot
    }
}
