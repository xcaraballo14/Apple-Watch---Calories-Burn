import Foundation

/// Live quest state the watch streams to the iPhone over HealthKit's
/// workout-session mirroring channel while a workout is running. JSON-encoded
/// on the wire and compiled into BOTH apps, so the format can't drift.
struct LiveQuestSnapshot: Codable, Equatable {
    var rewardNames: [String]
    var rewardEmojis: [String]
    var goalCalories: Int
    var caloriesBurned: Double
    var heartRate: Double
    var earnedCount: Int
    var startDate: Date

    var title: String {
        rewardNames.isEmpty ? "Quest" : rewardNames.joined(separator: " + ")
    }

    var emoji: String { rewardEmojis.first ?? "🔥" }

    var progress: Double {
        guard goalCalories > 0 else { return 0 }
        return min(caloriesBurned / Double(goalCalories), 1)
    }

    var caloriesLeft: Int {
        max(goalCalories - Int(caloriesBurned), 0)
    }
}
