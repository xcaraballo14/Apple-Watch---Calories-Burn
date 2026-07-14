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
    var isPaused: Bool
    var pausedSeconds: Double  // completed pause spans (excluded from elapsed)
    var pausedAt: Date?        // when the current pause began (nil while running)

    init(
        rewardNames: [String],
        rewardEmojis: [String],
        goalCalories: Int,
        caloriesBurned: Double,
        heartRate: Double,
        earnedCount: Int,
        startDate: Date,
        isPaused: Bool = false,
        pausedSeconds: Double = 0,
        pausedAt: Date? = nil
    ) {
        self.rewardNames = rewardNames
        self.rewardEmojis = rewardEmojis
        self.goalCalories = goalCalories
        self.caloriesBurned = caloriesBurned
        self.heartRate = heartRate
        self.earnedCount = earnedCount
        self.startDate = startDate
        self.isPaused = isPaused
        self.pausedSeconds = pausedSeconds
        self.pausedAt = pausedAt
    }

    /// Custom decode so a payload from a build that predates pause (no pause
    /// keys) still decodes instead of blanking the live card.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rewardNames    = try c.decode([String].self, forKey: .rewardNames)
        rewardEmojis   = try c.decode([String].self, forKey: .rewardEmojis)
        goalCalories   = try c.decode(Int.self, forKey: .goalCalories)
        caloriesBurned = try c.decode(Double.self, forKey: .caloriesBurned)
        heartRate      = try c.decode(Double.self, forKey: .heartRate)
        earnedCount    = try c.decode(Int.self, forKey: .earnedCount)
        startDate      = try c.decode(Date.self, forKey: .startDate)
        isPaused       = try c.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        pausedSeconds  = try c.decodeIfPresent(Double.self, forKey: .pausedSeconds) ?? 0
        pausedAt       = try c.decodeIfPresent(Date.self, forKey: .pausedAt)
    }

    /// Elapsed quest time at `date`, honoring pauses — frozen at the pause
    /// point while paused, and never counting paused spans. Matches the
    /// watch's own on-screen timer.
    func elapsedSeconds(at date: Date) -> TimeInterval {
        let reference = isPaused ? (pausedAt ?? date) : date
        return max(0, reference.timeIntervalSince(startDate) - pausedSeconds)
    }

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
