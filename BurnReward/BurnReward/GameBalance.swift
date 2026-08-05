import Foundation

/// Every systemic tuning number in one place — balancing is a one-file pass,
/// not a scavenger hunt. Engines (`XPEngine`, `LevelEngine`, `WeeklyChallenge`,
/// `NotificationService`) read these; **change values here, never inline**.
///
/// Two rules when tuning:
/// - XP changes must respect "never demotivate": factors ≥ 1, bonuses ≥ 0, so a
///   re-derived history can only level players UP.
/// - Anything that nudges (reminders, challenges) must tolerate rest — see the
///   health guardrails in ROADMAP.md.
///
/// Deliberately NOT here: the 30 badge thresholds (they live in `BadgeCatalog`,
/// each beside its human-readable requirement string, so number and copy can't
/// drift apart) and the level-title ladder (finalized by Xavier in `LevelEngine`).
enum GameBalance {

    // MARK: - XP formula v2 (XPEngine)

    /// Finishing the quest (earning the food) on top of burning the calories.
    static let questCompleteBonus = 25
    /// Showing up: the first quest started each calendar day.
    static let firstQuestOfDayBonus = 20
    /// Corrects the watch's undercounting of strength work.
    static let liftTypeFactor = 1.4
    /// XP per calorie for a workout BurnReward didn't run as a quest — anything
    /// arriving from Apple Health via another app, watch, or ring. Adjudicated
    /// 2026-07-14 (`RECORD_OLD_WORKOUTS.md`) and locked for launch in
    /// `LAUNCH_SCOPE.md`: outside work counts, quests count for more.
    ///
    /// Deliberately expressed as a **rate on the base**, never as a deduction
    /// row — a red "−68 XP" reads as a punishment for training outside the app,
    /// which is the exact resentment the aperture fix exists to remove. Same
    /// arithmetic either way; only this framing keeps the XP v2.1 promise that
    /// no factor is ever below 1 against the calories the player is credited.
    static let outsideWorkoutRate = 0.8
    /// Intensity multiplier bands from average heart rate, highest first.
    /// A workout's factor is the first band whose floor its avg HR reaches;
    /// below the lowest floor (or no HR) the factor is 1.0 — never a penalty.
    static let hrIntensityBands: [(minBPM: Int, factor: Double)] = [
        (160, 1.25),
        (140, 1.20),
        (120, 1.10),
        (100, 1.05),
    ]

    /// Precision bonus (XP v2.1): up to `precisionBonusMax` XP for an *earned*
    /// quest that lands near its calorie goal, tapering linearly to 0 once
    /// overshoot reaches `precisionBonusFalloff` (a fraction of the goal). A
    /// pure bonus — always ≥ 0, so it can only raise a quest's XP. This is the
    /// mechanic that rewards control over raw max burn (precision = the skill).
    static let precisionBonusMax = 50
    static let precisionBonusFalloff = 0.30   // 30% over goal → no bonus

    // MARK: - Level curve (LevelEngine)

    /// Total XP to *become* level L is `quad·n² + linear·n` where n = L − 1:
    /// L2 = 500, L3 = 1,200, L4 = 2,100, L5 = 3,200 …
    static let levelCurveQuadratic = 100
    static let levelCurveLinear = 400

    // MARK: - Weekly challenges (WeeklyChallenge)

    static let challengeSpreeQuests = 4          // 🗡️ QUEST SPREE
    static let challengePrecisionQuests = 3      // 🎯 PRECISION WEEK
    /// "Within the goal" = earned, and no more than this fraction over it.
    /// Shared with the precision badges' intent (10%).
    static let challengePrecisionTolerance = 0.10
    static let challengeMenuClasses = 3          // 🧭 DUNGEON MENU
    static let challengeBigBurnCalories = 1_500  // 🔥 BIG BURN
    static let challengeLongHaulMinutes = 120    // ⏳ LONG HAUL

    // MARK: - Nudges (NotificationService / toasts)

    /// Streak reminder only fires while a streak of at least this many days
    /// is alive (a 1-day "streak" isn't a thing worth protecting yet).
    static let streakReminderMinDays = 2
    /// Challenge reminder only fires when the week's challenge is at least
    /// this far along — no engagement means silence, not homework.
    static let challengeReminderMinFraction = 0.5
    /// Celebration toast dwell before auto-dismiss.
    static let toastSeconds: Double = 4
    static let toastSecondsVoiceOver: Double = 8
}
