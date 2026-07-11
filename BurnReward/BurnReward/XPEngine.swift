import Foundation

/// The itemized XP receipt for one quest. Attribution is sequential
/// (base → type → intensity), so the visible lines always sum to `total`.
struct XPBreakdown: Hashable {
    let baseCalories: Int
    let typeFactor: Double
    let intensityFactor: Double
    let earnedBonus: Int
    let firstOfDayBonus: Int
    let precisionBonus: Int

    /// Calories after both multipliers, rounded once.
    var multipliedBase: Int {
        Int((Double(baseCalories) * typeFactor * intensityFactor).rounded())
    }

    /// XP added by the type factor alone.
    var typeXP: Int {
        Int((Double(baseCalories) * typeFactor).rounded()) - baseCalories
    }

    /// XP added by the intensity factor — absorbs the rounding remainder so
    /// baseCalories + typeXP + intensityXP == multipliedBase exactly.
    var intensityXP: Int { multipliedBase - baseCalories - typeXP }

    var total: Int { multipliedBase + earnedBonus + firstOfDayBonus + precisionBonus }
}

/// XP formula v2.1 — replaces v1's flat "1 cal = 1 XP".
///
///     XP = round(activeCalories × typeFactor × intensityFactor)
///          + questCompleteBonus + firstQuestOfDayBonus + precisionBonus
///
/// Design constraints, in priority order:
/// - Never demotivate: every factor is ≥ 1 and every bonus is ≥ 0, so no
///   workout scores below its v1 value and migration can only raise levels.
/// - Precision is the skill (v2.1): landing near the goal earns a small extra
///   bonus that rewards control over raw overshoot — additive, never a penalty.
/// - Type balance: the type factor compensates for what the watch's HR-based
///   calorie estimate under-measures (strength work); it does not rank which
///   exercise is "better".
/// - Intensity counts: heart-rate bands let a short hard session compete with
///   a long easy one without ever punishing the long one.
/// - Fully derived from HealthKit, like `LevelEngine`: a reinstall recomputes
///   the exact same totals — no separate XP store to corrupt or migrate.
enum XPEngine {
    /// Finishing the quest (earning the food) on top of burning the calories.
    /// Flat, so it's proportionally biggest on small quests.
    static let questCompleteBonus = GameBalance.questCompleteBonus
    /// Showing up: the first quest started each calendar day.
    static let firstQuestOfDayBonus = GameBalance.firstQuestOfDayBonus

    /// Strength training reads low on active calories (rest between sets,
    /// afterburn, muscle work heart rate doesn't capture) — corrected here.
    static func typeFactor(forActivityLabel label: String) -> Double {
        label == "LIFT" ? GameBalance.liftTypeFactor : 1.0
    }

    /// Generic adult bands from the workout's average heart rate; missing HR
    /// means no bonus, never a penalty. Future: personal zones once date of
    /// birth is read from HealthKit (HRmax ≈ 208 − 0.7 × age).
    static func intensityFactor(forAverageHR bpm: Int?) -> Double {
        guard let bpm else { return 1.0 }
        return GameBalance.hrIntensityBands.first { bpm >= $0.minBPM }?.factor ?? 1.0
    }

    /// Precision bonus: rewards an *earned* quest for landing near its goal.
    /// Full bonus at (or under) the goal, tapering linearly to zero once
    /// overshoot reaches the falloff. Unfinished quests and goal-less quests
    /// earn nothing — you can only be "precise" about a target you hit.
    static func precisionBonus(calories: Int, goal: Int?, earned: Bool) -> Int {
        guard earned, let goal, goal > 0 else { return 0 }
        let overshoot = Double(max(0, calories - goal)) / Double(goal)
        let closeness = max(0, 1 - overshoot / GameBalance.precisionBonusFalloff)
        return Int((closeness * Double(GameBalance.precisionBonusMax)).rounded())
    }

    static func score(_ quest: Quest, isFirstQuestOfDay: Bool) -> XPBreakdown {
        XPBreakdown(
            baseCalories: quest.calories,
            typeFactor: typeFactor(forActivityLabel: quest.activityLabel),
            intensityFactor: intensityFactor(forAverageHR: quest.averageHeartRate),
            earnedBonus: quest.earned ? questCompleteBonus : 0,
            firstOfDayBonus: isFirstQuestOfDay ? firstQuestOfDayBonus : 0,
            precisionBonus: precisionBonus(calories: quest.calories, goal: quest.goalCalories, earned: quest.earned)
        )
    }

    /// Scores the whole history in one pass, independent of input order: the
    /// daily bonus goes to the quest that *started* first each calendar day,
    /// ties broken by id, so every re-fetch reproduces the same totals.
    static func scoreAll(_ quests: [Quest], calendar: Calendar = .current) -> [UUID: XPBreakdown] {
        var earliest: [Date: (start: Date, id: UUID)] = [:]
        for quest in quests {
            let day = calendar.startOfDay(for: quest.startDate)
            if let current = earliest[day],
               (current.start, current.id.uuidString) <= (quest.startDate, quest.id.uuidString) {
                continue
            }
            earliest[day] = (quest.startDate, quest.id)
        }
        let dailyWinners = Set(earliest.values.map(\.id))

        var scores: [UUID: XPBreakdown] = [:]
        scores.reserveCapacity(quests.count)
        for quest in quests {
            scores[quest.id] = score(quest, isFirstQuestOfDay: dailyWinners.contains(quest.id))
        }
        return scores
    }

    static func totalXP(_ quests: [Quest], calendar: Calendar = .current) -> Int {
        scoreAll(quests, calendar: calendar).values.reduce(0) { $0 + $1.total }
    }
}
