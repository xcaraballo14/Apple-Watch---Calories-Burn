import Foundation

/// Custom HealthKit metadata keys stamped onto every workout BurnReward saves.
/// The iPhone app reconstructs quest history (which reward, the goal, whether it
/// was earned) straight from these, so the keys are a stable contract between
/// the two apps — bump `currentSchemaVersion` if the format ever changes.
///
/// Compiled into BOTH the watch app and the iOS app.
enum QuestMetadata {
    static let schemaVersion = "com.burnreward.schemaVersion"  // Int
    static let rewardNames   = "com.burnreward.rewardNames"    // "Donut|Taco" (picker order, ascending calories)
    static let rewardEmojis  = "com.burnreward.rewardEmojis"   // "🍩|🌮" (same order as names)
    static let goalCalories  = "com.burnreward.goalCalories"   // Int — combo total the quest aimed for
    static let earnedCount   = "com.burnreward.earnedCount"    // Int — milestones cleared when the workout ended
    static let rewardCount   = "com.burnreward.rewardCount"    // Int — rewards in the combo

    static let currentSchemaVersion = 1

    /// Joins/splits the name and emoji lists. Safe because reward names never
    /// contain a pipe (enforced by the built-in list today; keep it true for
    /// custom rewards later).
    static let separator = "|"
}
