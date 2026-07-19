import Foundation
import HealthKit

/// One completed (or abandoned) BurnReward workout, reconstructed from the
/// HKWorkout the watch saved. HealthKit is the source of truth — nothing here
/// is stored anywhere else.
struct Quest: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let calories: Int
    let averageHeartRate: Int?
    let steps: Int?                  // nil when the workout carries no step data
    let activityLabel: String        // WALK / RUN / BIKE / LIFT / OTHER
    let rewardNames: [String]
    let rewardEmojis: [String]
    let goalCalories: Int?
    let earned: Bool
    /// Saved before the watch stamped reward metadata — shows as a generic quest.
    let isLegacy: Bool

    var title: String {
        rewardNames.isEmpty ? "Quest Workout" : rewardNames.joined(separator: " + ")
    }

    var emoji: String { rewardEmojis.first ?? "🔥" }

    var progressToGoal: Double? {
        guard let goalCalories, goalCalories > 0 else { return nil }
        return min(Double(calories) / Double(goalCalories), 1.0)
    }
}

extension Quest {
    init(workout: HKWorkout) {
        id = workout.uuid
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration

        let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
        calories = Int(energy ?? 0)

        let bpm = workout.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?
            .doubleValue(for: .count().unitDivided(by: .minute()))
        averageHeartRate = bpm.map(Int.init)

        let stepCount = workout.statistics(for: HKQuantityType(.stepCount))?
            .sumQuantity()?
            .doubleValue(for: .count())
        steps = stepCount.map(Int.init)

        activityLabel = workout.workoutActivityType.brLabel

        let meta = workout.metadata ?? [:]
        if let names = meta[QuestMetadata.rewardNames] as? String, !names.isEmpty {
            rewardNames = names.components(separatedBy: QuestMetadata.separator)
            let emojis = meta[QuestMetadata.rewardEmojis] as? String ?? ""
            rewardEmojis = emojis.isEmpty
                ? []
                : emojis.components(separatedBy: QuestMetadata.separator)
            goalCalories = meta[QuestMetadata.goalCalories] as? Int
            let earnedCount = meta[QuestMetadata.earnedCount] as? Int ?? 0
            let rewardCount = meta[QuestMetadata.rewardCount] as? Int ?? rewardNames.count
            earned = rewardCount > 0 && earnedCount >= rewardCount
            isLegacy = false
        } else {
            rewardNames = []
            rewardEmojis = []
            goalCalories = nil
            earned = true   // pre-metadata workouts were saved at quest completion
            isLegacy = true
        }
    }
}

private extension HKWorkoutActivityType {
    var brLabel: String {
        switch self {
        case .walking:                     "WALK"
        case .running:                     "RUN"
        case .cycling:                     "BIKE"
        case .traditionalStrengthTraining: "LIFT"
        default:                           "OTHER"
        }
    }
}

// MARK: - Level engine

/// The XP spine for the long-term progression system. Deterministic and fully
/// derived from HealthKit, so a reinstall recomputes the exact same level.
enum LevelEngine {
    /// Total XP at which you *become* `level`. Level 1 starts at 0; the gap to
    /// the next level widens as you climb (classic RPG pacing):
    /// L2 = 500, L3 = 1,200, L4 = 2,100, L5 = 3,200 …
    static func xpToReach(_ level: Int) -> Int {
        let n = max(0, level - 1)
        return GameBalance.levelCurveQuadratic * n * n + GameBalance.levelCurveLinear * n
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpToReach(level + 1) <= xp { level += 1 }
        return level
    }

    struct Progress {
        let level: Int
        let title: String
        let xpIntoLevel: Int
        let xpLevelSpan: Int

        var fraction: Double {
            guard xpLevelSpan > 0 else { return 0 }
            return min(Double(xpIntoLevel) / Double(xpLevelSpan), 1.0)
        }
    }

    static func progress(forXP xp: Int) -> Progress {
        let level = level(forXP: xp)
        let floor = xpToReach(level)
        let ceiling = xpToReach(level + 1)
        return Progress(
            level: level,
            title: title(for: level),
            xpIntoLevel: xp - floor,
            xpLevelSpan: ceiling - floor
        )
    }

    /// Title ladder finalized with Xavier 2026-07-08. Food-RPG voice with a
    /// scavenger → knight → legend ascension; "Squire → Knight → Baron → Paladin"
    /// is the deliberate spine, and FEAST PHANTOM → FEAST OVERLORD caps it as a duo.
    static func title(for level: Int) -> String {
        switch level {
        case ..<2:    "SNACK ROOKIE"
        case 2:       "CRUMB COLLECTOR"
        case 3:       "SNACK SQUIRE"
        case 4:       "CARB CRUSADER"
        case 5:       "TREAT TACTICIAN"
        case 6:       "SNACK SLAYER"
        case 7:       "DUNGEON DINER"
        case 8:       "CALORIE KNIGHT"
        case 9:       "BURN BARON"
        case 10...11: "DONUT DESTROYER"
        case 12...14: "PIZZA PALADIN"
        case 15...19: "BURRITO BERSERKER"
        case 20...29: "FEAST PHANTOM"
        default:      "FEAST OVERLORD"
        }
    }
}

// MARK: - Dashboard aggregates

/// Everything the Home screen shows, computed in one pass over the quest list.
struct DashboardStats {
    let totalXP: Int
    let levelProgress: LevelEngine.Progress
    let questsThisWeek: Int
    let caloriesThisWeek: Int
    /// One flag per day of the current week (calendar order, e.g. Sun…Sat).
    let weekDayFlags: [Bool]
    let weekDaySymbols: [String]
    let todayWeekIndex: Int
    let streakDays: Int
    let rewardsWon: Int
    let allTimeCalories: Int

    init(quests: [Quest], now: Date = .now, calendar: Calendar = .current) {
        totalXP = XPEngine.totalXP(quests, calendar: calendar)
        levelProgress = LevelEngine.progress(forXP: totalXP)
        allTimeCalories = quests.reduce(0) { $0 + $1.calories }
        rewardsWon = quests.filter(\.earned)
            .reduce(0) { $0 + max($1.rewardNames.count, 1) }

        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekQuests = quests.filter { quest in
            guard let week else { return false }
            return week.contains(quest.endDate)
        }
        questsThisWeek = weekQuests.filter(\.earned).count
        caloriesThisWeek = weekQuests.reduce(0) { $0 + $1.calories }

        let earnedDays = Set(
            quests.filter(\.earned).map { calendar.startOfDay(for: $0.endDate) }
        )

        var flags: [Bool] = []
        var symbols: [String] = []
        var todayIndex = 0
        if let weekStart = week?.start {
            let formatter = DateFormatter()
            let narrow = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
            for offset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                flags.append(earnedDays.contains(calendar.startOfDay(for: day)))
                let weekdayNumber = calendar.component(.weekday, from: day)
                symbols.append(narrow[(weekdayNumber - 1) % narrow.count])
                if calendar.isDate(day, inSameDayAs: now) { todayIndex = offset }
            }
        }
        weekDayFlags = flags
        weekDaySymbols = symbols
        todayWeekIndex = todayIndex

        // Streak: consecutive days with an earned quest, ending today (or
        // yesterday, so an evening workout isn't "broken" the next morning).
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        if !earnedDays.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while earnedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        streakDays = streak
    }
}

// MARK: - Character sheet (Profile)

/// Everything the Profile "character sheet" shows, derived entirely from the
/// HealthKit quest list — nothing here is stored separately, so a reinstall
/// rebuilds the exact same sheet. Pure Foundation (no SwiftUI): the view maps
/// these to colors and glyphs.

/// The RPG name + glyph for each workout class. Fixed mapping; the fifth
/// (WILDCARD) is the catch-all for any non-core workout type.
enum CharacterClass {
    static let coreOrder = ["RUN", "WALK", "BIKE", "LIFT"]

    static func name(for label: String) -> String {
        switch label {
        case "RUN":  "STRIDER"
        case "WALK": "WAYFARER"
        case "BIKE": "OUTRIDER"
        case "LIFT": "JUGGERNAUT"
        default:     "WILDCARD"
        }
    }

    static func emoji(for label: String) -> String {
        switch label {
        case "RUN":  "🏃"
        case "WALK": "🚶"
        case "BIKE": "🚴"
        case "LIFT": "🏋️"
        default:     "🎲"
        }
    }
}

/// One class tile: how many quests you've logged in that class (all attempts,
/// not just earned — affinity is about where you spend your time).
struct ClassAffinity: Identifiable {
    let label: String     // raw activityLabel
    let name: String      // STRIDER / WAYFARER / …
    let emoji: String
    let count: Int
    let isMain: Bool      // the class you've done most
    var id: String { label }

    /// The four core classes always appear; WILDCARD only when the player has
    /// actually logged an "other" quest, so most sheets stay a clean four.
    static func all(for quests: [Quest]) -> [ClassAffinity] {
        var counts: [String: Int] = [:]
        for quest in quests {
            let key = CharacterClass.coreOrder.contains(quest.activityLabel) ? quest.activityLabel : "OTHER"
            counts[key, default: 0] += 1
        }
        var order = CharacterClass.coreOrder
        if (counts["OTHER"] ?? 0) > 0 { order.append("OTHER") }

        // Main = the class with the most quests; ties break by display order.
        // A player with no quests has no main (nothing highlighted).
        let topCount = order.compactMap { counts[$0] }.max() ?? 0
        let mainLabel = topCount > 0 ? order.first { counts[$0] == topCount } : nil

        return order.map { label in
            ClassAffinity(
                label: label,
                name: CharacterClass.name(for: label),
                emoji: CharacterClass.emoji(for: label),
                count: counts[label] ?? 0,
                isMain: label == mainLabel
            )
        }
    }
}

/// A personal best, plus the quest that set it (for a date subtitle and a tap
/// target). `quest` is nil when the record isn't a single workout (best streak)
/// or when there's no data yet.
struct PersonalRecord: Identifiable {
    enum Kind: String { case burn, duration, steps, heartRate, streak }
    let kind: Kind
    let value: String       // already formatted; "—" when there's no data
    let detail: String      // "Cookie + Milkshake · Jun 21" or "All-time"
    let quest: Quest?
    var id: String { kind.rawValue }

    static func all(for quests: [Quest], calendar: Calendar = .current) -> [PersonalRecord] {
        func record(_ kind: Kind, best: Quest?, value: (Quest) -> String) -> PersonalRecord {
            guard let best else { return PersonalRecord(kind: kind, value: "—", detail: "No quests yet", quest: nil) }
            let day = best.endDate.formatted(.dateTime.month(.abbreviated).day())
            return PersonalRecord(kind: kind, value: value(best), detail: "\(best.title) · \(day)", quest: best)
        }

        // Only earned quests can hold a record — an unfinished quest never
        // "wins" a trophy (matches DashboardViewModel.detectRecordBreaks, the
        // badge ladders, and bestStreak below; keeps the History 🏆 stamp off
        // UNFINISHED rows). Records stay derived; no new storage.
        let earned = quests.filter(\.earned)
        let biggestBurn = earned.max { $0.calories < $1.calories }
        let longest = earned.max { $0.duration < $1.duration }
        let mostSteps = earned.compactMap { q in q.steps.map { ($0, q) } }.max { $0.0 < $1.0 }?.1
        let topHR = earned.compactMap { q in q.averageHeartRate.map { ($0, q) } }.max { $0.0 < $1.0 }?.1

        let streak = bestStreak(quests, calendar: calendar)
        let streakRecord = PersonalRecord(
            kind: .streak,
            value: streak > 0 ? "\(streak) DAY\(streak == 1 ? "" : "S")" : "—",
            detail: streak > 0 ? "All-time best" : "No streak yet",
            quest: nil
        )

        return [
            record(.burn, best: biggestBurn) { "\($0.calories) CAL" },
            record(.duration, best: longest) { BRFormat.duration($0.duration) },
            record(.steps, best: mostSteps) { ($0.steps ?? 0).formatted() },
            record(.heartRate, best: topHR) { "\($0.averageHeartRate ?? 0) BPM" },
            streakRecord,
        ]
    }

    /// Longest run of consecutive calendar days that each hold an earned quest.
    /// Distinct from `DashboardStats.streakDays`, which is the *current* streak.
    static func bestStreak(_ quests: [Quest], calendar: Calendar = .current) -> Int {
        let days = Set(quests.filter(\.earned).map { calendar.startOfDay(for: $0.endDate) })
        var best = 0
        for day in days {
            // Only count from the start of a run (the previous day is a gap).
            let previous = calendar.date(byAdding: .day, value: -1, to: day)
            if let previous, days.contains(previous) { continue }
            var length = 1
            var cursor = day
            while let next = calendar.date(byAdding: .day, value: 1, to: cursor), days.contains(next) {
                length += 1
                cursor = next
            }
            best = max(best, length)
        }
        return best
    }
}

/// One trophy. `earned` drives gold-vs-locked rendering; `requirement` is shown
/// on locked badges (and read by VoiceOver) so there's always a clear next goal.
/// `progress` is attached to the quantifiable ladders (burn, duration, steps,
/// grind, rewards, streak) so the detail sheet can show "700 / 1,000 cal" —
/// event-shaped badges (precision, comeback, time-of-day) carry nil.
struct Badge: Identifiable, Equatable {
    struct Progress: Equatable {
        let current: Int
        let target: Int
        let unit: String     // "cal" / "min" / "steps" / "quests" / "rewards" / "days"
        var fraction: Double { target > 0 ? min(Double(current) / Double(target), 1) : 0 }
    }

    let id: String
    let emoji: String
    let name: String
    let requirement: String
    let earned: Bool
    let progress: Progress?
    var flavor: String = ""       // retro one-liner shown in the detail sheet
    var earnedDate: Date? = nil   // when first satisfied (derived + cached, not stored)

    func withEarnedDate(_ date: Date?) -> Badge {
        var copy = self
        copy.earnedDate = date
        return copy
    }
}

/// The full v1 trophy catalog. Every predicate is a pure function of the quest
/// history (calories, duration, avg HR, steps, class, goal, reward count, dates)
/// — deliberately no heart-rate-zone or reward-type badges yet, since those need
/// data the model doesn't carry. Catalog order is the authoring order; the view
/// sorts earned-first for display.
enum BadgeCatalog {
    static func all(for quests: [Quest], stats: DashboardStats, calendar: Calendar = .current) -> [Badge] {
        let earned = quests.filter(\.earned)
        let earnedCount = earned.count
        let rewardsWon = stats.rewardsWon
        let bestStreak = PersonalRecord.bestStreak(quests, calendar: calendar)

        let maxBurn = earned.map(\.calories).max() ?? 0
        let maxDuration = earned.map(\.duration).max() ?? 0
        let maxSteps = earned.compactMap(\.steps).max() ?? 0

        // Quests grouped by earned-day and by calendar week, reused below.
        let byDay = Dictionary(grouping: earned) { calendar.startOfDay(for: $0.endDate) }
        func weekStart(_ date: Date) -> Date? { calendar.dateInterval(of: .weekOfYear, for: date)?.start }
        let earnedWeeks = Set(earned.compactMap { weekStart($0.endDate) })
        let classesLogged = Set(quests.map { CharacterClass.coreOrder.contains($0.activityLabel) ? $0.activityLabel : "OTHER" })
        let coreClassesLogged = classesLogged.intersection(CharacterClass.coreOrder)

        // Precision: earned quests that reached goal without overshooting by > p.
        func withinGoal(_ p: Double) -> Bool {
            earned.contains { quest in
                guard let goal = quest.goalCalories, goal > 0 else { return false }
                let ratio = Double(quest.calories) / Double(goal)
                return ratio >= 1 && ratio <= 1 + p
            }
        }

        // Gap: any earned quest that follows the previous one by ≥ n days.
        let earnedDates = earned.map(\.endDate).sorted()
        func hasGap(days n: Int) -> Bool {
            zip(earnedDates, earnedDates.dropFirst()).contains { earlier, later in
                (calendar.dateComponents([.day], from: earlier, to: later).day ?? 0) >= n
            }
        }

        // Consecutive weeks each holding ≥ 1 earned quest.
        func consecutiveWeeks(_ n: Int) -> Bool {
            for week in earnedWeeks {
                if let prior = calendar.date(byAdding: .weekOfYear, value: -1, to: week), earnedWeeks.contains(prior) { continue }
                var length = 1
                var cursor = week
                while let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor), earnedWeeks.contains(next) {
                    length += 1
                    cursor = next
                }
                if length >= n { return true }
            }
            return false
        }

        // Distinct classes within any single week.
        let classesPerWeek = Dictionary(grouping: earned) { weekStart($0.endDate) }
            .mapValues { Set($0.map(\.activityLabel)) }
        let maxClassesInWeek = classesPerWeek.values.map(\.count).max() ?? 0

        // Earned quests per class (for Class Master).
        var perClassEarned: [String: Int] = [:]
        for quest in earned { perClassEarned[quest.activityLabel, default: 0] += 1 }
        let topClassEarned = perClassEarned.values.max() ?? 0

        func startHour(_ quest: Quest) -> Int { calendar.component(.hour, from: quest.startDate) }
        func endHour(_ quest: Quest) -> Int { calendar.component(.hour, from: quest.endDate) }

        func badge(_ id: String, _ emoji: String, _ name: String, _ requirement: String, _ flavor: String,
                   _ earned: Bool, _ progress: Badge.Progress? = nil) -> Badge {
            Badge(id: id, emoji: emoji, name: name, requirement: requirement,
                  earned: earned, progress: progress, flavor: flavor)
        }
        // Progress helpers for the quantifiable ladders.
        func cal(_ target: Int) -> Badge.Progress { .init(current: maxBurn, target: target, unit: "cal") }
        func mins(_ target: Int) -> Badge.Progress { .init(current: Int(maxDuration / 60), target: target, unit: "min") }
        func steps(_ target: Int) -> Badge.Progress { .init(current: maxSteps, target: target, unit: "steps") }
        func questsDone(_ target: Int) -> Badge.Progress { .init(current: earnedCount, target: target, unit: "quests") }
        func rewards(_ target: Int) -> Badge.Progress { .init(current: rewardsWon, target: target, unit: "rewards") }

        return [
            // Onboarding
            badge("first_burn", "🔥", "First Burn", "Finish your first quest",
                  "Every legend starts with a single spark.", earnedCount >= 1),
            badge("decade", "🔟", "Decade", "Complete 10 quests",
                  "Ten quests down. The habit is taking hold.", earnedCount >= 10, questsDone(10)),
            badge("full_party", "🎲", "Full Party", "Log a quest in all four core classes",
                  "Run, walk, ride, and lift. A true all-rounder.", coreClassesLogged.count == 4),
            // Burn ladder
            badge("spark", "⚡", "Spark", "Burn 250+ calories in one quest",
                  "Your first taste of a real burn.", maxBurn >= 250, cal(250)),
            badge("inferno", "🌋", "Inferno", "Burn 500+ calories in one quest",
                  "You brought the heat, and then some.", maxBurn >= 500, cal(500)),
            badge("titan", "🏔️", "Titan", "Burn 800+ calories in one quest",
                  "Few ever reach this kind of output.", maxBurn >= 800, cal(800)),
            badge("dragon_slayer", "🐉", "Dragon Slayer", "Burn 1,000+ calories in one quest",
                  "A thousand calories in one quest. Monstrous.", maxBurn >= 1000, cal(1000)),
            // Duration ladder
            badge("long_walk", "🥾", "Long Walk", "A quest lasting 30+ minutes",
                  "Half an hour of steady, honest effort.", maxDuration >= 30 * 60, mins(30)),
            badge("marathoner", "⏱️", "Marathoner", "A quest lasting 60+ minutes",
                  "A full hour on the clock. Relentless.", maxDuration >= 60 * 60, mins(60)),
            badge("endurance_tank", "🛡️", "Endurance Tank", "A quest lasting 90+ minutes",
                  "Ninety minutes deep and still standing.", maxDuration >= 90 * 60, mins(90)),
            // Steps ladder
            badge("foot_soldier", "🐾", "Foot Soldier", "5,000+ steps in one quest",
                  "Five thousand steps, boots on the ground.", maxSteps >= 5000, steps(5000)),
            badge("trailblazer", "👣", "Trailblazer", "10,000+ steps in one quest",
                  "Ten thousand steps. You set the trail.", maxSteps >= 10000, steps(10000)),
            badge("long_march", "🧗", "Long March", "15,000+ steps in one quest",
                  "Fifteen thousand steps. The march goes on.", maxSteps >= 15000, steps(15000)),
            // Precision ladder
            badge("strategist", "🧠", "Strategist", "Finish within 10% of the goal",
                  "Close to the mark. No wasted motion.", withinGoal(0.10)),
            badge("sharpshooter", "🎯", "Sharpshooter", "Finish within 5% of the goal",
                  "Dead-on aim. Barely a calorie to spare.", withinGoal(0.05)),
            badge("needle_threader", "🪡", "Needle Threader", "Finish within 2% of the goal",
                  "Within two percent. Surgical precision.", withinGoal(0.02)),
            // Consistency
            badge("week_warrior", "📅", "Week Warrior", "Reach a 7-day quest streak",
                  "Seven days straight. Discipline pays.", bestStreak >= 7,
                  .init(current: bestStreak, target: 7, unit: "days")),
            badge("brick_by_brick", "🧱", "Brick by Brick", "At least one quest a week for 4 weeks",
                  "One quest a week, laid brick by brick.", consecutiveWeeks(4)),
            badge("double_feature", "🌗", "Double Feature", "Two or more quests in one day",
                  "Two quests, one day. Double the glory.", byDay.values.contains { $0.count >= 2 }),
            // Comeback
            badge("comeback", "🔁", "Comeback", "Earn a quest after a 7+ day break",
                  "Back after a week away. Welcome home.", hasGap(days: 7)),
            badge("back_from_dead", "🧟", "Back From the Dead", "Earn a quest after a 30+ day break",
                  "Thirty days gone, and you rose again.", hasGap(days: 30)),
            // Variety
            badge("multiclass", "🧩", "Multiclass", "Three different classes in one week",
                  "Three disciplines in a single week.", maxClassesInWeek >= 3),
            badge("class_master", "🧙", "Class Master", "Complete 10 quests in one class",
                  "Ten in one class. You've mastered the craft.", topClassEarned >= 10),
            // Time of day
            badge("dawn_raid", "🌅", "Dawn Raid", "Start a quest before 7 AM",
                  "Up before dawn while the world sleeps.", quests.contains { startHour($0) < 7 }),
            badge("night_owl", "🦉", "Night Owl", "Finish a quest after 9 PM",
                  "Burning bright long after sunset.", quests.contains { endHour($0) >= 21 }),
            // Rewards
            badge("sweet_ten", "🍭", "Sweet Ten", "Win 10 rewards",
                  "Ten treats earned, every one honest.", rewardsWon >= 10, rewards(10)),
            badge("paid_in_sweat", "💰", "Paid in Sweat", "Win 25 rewards",
                  "Twenty-five rewards, paid in full.", rewardsWon >= 25, rewards(25)),
            badge("combo_king", "👑", "Combo King", "Earn a two-reward combo quest",
                  "Two treats in one quest. Greedy, but earned.", earned.contains { $0.rewardNames.count >= 2 }),
            // Grind apex
            badge("centurion", "💯", "Centurion", "Complete 100 quests",
                  "One hundred quests. A veteran now.", earnedCount >= 100, questsDone(100)),
            badge("legend", "🏛️", "Legend", "Complete 250 quests",
                  "Two hundred fifty quests. The name fits.", earnedCount >= 250, questsDone(250)),
        ]
    }

    /// Date each earned badge was first satisfied — replays the log, reusing
    /// `all` so the predicates can't drift from the sheet. O(n²) in quest count,
    /// but n is small; compute once in the setQuests funnel, never per render.
    static func earnedDates(for quests: [Quest], calendar: Calendar = .current) -> [String: Date] {
        let sorted = quests.sorted { $0.endDate < $1.endDate }
        var running: [Quest] = []
        var dates: [String: Date] = [:]
        for quest in sorted {
            running.append(quest)
            let earned = all(for: running, stats: DashboardStats(quests: running), calendar: calendar)
                .filter(\.earned)
            for badge in earned where dates[badge.id] == nil {
                dates[badge.id] = quest.endDate
            }
        }
        return dates
    }
}

// MARK: - Celebrations (toast payloads)

/// One thing worth interrupting the player for — a badge unlock or a broken
/// personal record. The toast overlay renders these uniformly; the queue lives
/// in the dashboard model. Heart-rate and streak records deliberately never
/// become celebrations (never cheer a high BPM; a live streak would toast daily).
struct Celebration: Identifiable, Equatable {
    enum Kind: Equatable { case badge, record }
    let id: String
    let kind: Kind
    let emoji: String
    let headline: String   // "BADGE EARNED!" / "NEW RECORD!"
    let title: String      // "DRAGON SLAYER" / "BIGGEST BURN · 812 CAL"
    let detail: String     // requirement / "Pizza Slice · beats 700 cal"

    init(id: String, kind: Kind, emoji: String, headline: String, title: String, detail: String) {
        self.id = id
        self.kind = kind
        self.emoji = emoji
        self.headline = headline
        self.title = title
        self.detail = detail
    }

    init(badge: Badge) {
        self.init(
            id: "badge_\(badge.id)", kind: .badge, emoji: badge.emoji,
            headline: "BADGE EARNED!", title: badge.name.uppercased(),
            detail: badge.requirement
        )
    }
}

// MARK: - Alerts feed (bell)

/// One entry in the alerts feed. Pure data — every field is derived from quest
/// history + level state, so there's no backend and a reinstall rebuilds the
/// same feed. `date` is nil for live nudges ("Now") and set for past events
/// (which is also what drives the unread dot).
/// How close a nudge is to done. Shown as a bar so "3 quests from QUEST
/// SPREE" carries its own progress instead of just naming a gap.
struct AlertProgress: Equatable {
    let current: Int
    let target: Int
    /// Suffix for the readout: "1/4" (empty) vs "268 / 300 XP".
    let unit: String
    /// The bar's colour follows what's being measured, not the row.
    let tint: AlertProgressTint

    var fraction: Double {
        target > 0 ? min(Double(current) / Double(target), 1) : 0
    }

    var readout: String {
        unit.isEmpty
            ? "\(current)/\(target)"
            : "\(current.formatted()) / \(target.formatted()) \(unit)"
    }
}

/// Named rather than a Color so the pure-model layer stays free of SwiftUI.
enum AlertProgressTint: Equatable { case green, gold, orange }

struct AlertItem: Identifiable, Equatable {
    /// The first three are *derived* from quest history by `AlertFeed`. The
    /// social kinds are *fetched* from Supabase by `SocialAlertStore` — they
    /// are the one part of this feed a reinstall can't rebuild offline, which
    /// is why they live in a separate store rather than in `AlertFeed`.
    enum Kind: Equatable {
        case nudge, streak, badge, levelUp, record
        case friendRequest, friendJoined, reaction

        var isSocial: Bool {
            switch self {
            case .friendRequest, .friendJoined, .reaction: true
            default: false
            }
        }
    }
    let id: String
    let kind: Kind
    let emoji: String
    let title: String
    let detail: String
    let time: String
    let date: Date?
    var progress: AlertProgress? = nil
}

/// Builds the bell feed: forward-looking nudges from the current state, plus a
/// history of achievement events reconstructed by replaying the quest log — so
/// the "Reached Level 6" / "Earned Dragon Slayer" dates are real, not faked.
enum AlertFeed {
    static func build(
        quests: [Quest],
        scores: [UUID: XPBreakdown],
        stats: DashboardStats,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (nudges: [AlertItem], recent: [AlertItem]) {
        (nudges: nudges(quests: quests, stats: stats, now: now, calendar: calendar),
         recent: recent(quests: quests, scores: scores, now: now, calendar: calendar))
    }

    // MARK: Nudges — forward-looking, from the current state

    private static func nudges(
        quests: [Quest],
        stats: DashboardStats,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [AlertItem] {
        var items: [AlertItem] = []
        let progress = stats.levelProgress

        // This week's challenge — show the gap, never the guilt (gone once done).
        if let challenge = WeeklyChallenge.current(for: quests, now: now, calendar: calendar),
           !challenge.isComplete {
            let remaining = challenge.goal - challenge.progress
            items.append(AlertItem(
                id: "nudge_challenge", kind: .nudge, emoji: challenge.emoji,
                title: "\(remaining.formatted()) \(challenge.unitLabel(for: remaining)) from \(challenge.name)",
                detail: challenge.detail,
                time: "Now", date: nil,
                progress: AlertProgress(current: challenge.progress, target: challenge.goal,
                                        unit: "", tint: .green)
            ))
        }

        // Progress to the next level (skipped only at the very top of the ladder).
        if progress.xpLevelSpan > 0 {
            let toGo = max(progress.xpLevelSpan - progress.xpIntoLevel, 0)
            items.append(AlertItem(
                id: "nudge_level", kind: .nudge, emoji: "✨",
                title: "\(toGo.formatted()) XP to Level \(progress.level + 1)",
                detail: "Next rank: \(LevelEngine.title(for: progress.level + 1))",
                time: "Now", date: nil,
                progress: AlertProgress(current: progress.xpIntoLevel,
                                        target: progress.xpLevelSpan,
                                        unit: "XP", tint: .gold)
            ))
        }

        // The locked badge you're closest to finishing.
        let closest = BadgeCatalog.all(for: quests, stats: stats)
            .filter { !$0.earned }
            .compactMap { badge -> (badge: Badge, fraction: Double, remaining: Int)? in
                guard let p = badge.progress, p.current < p.target, p.fraction > 0 else { return nil }
                return (badge, p.fraction, p.target - p.current)
            }
            .max { $0.fraction < $1.fraction }
        if let closest, let p = closest.badge.progress {
            items.append(AlertItem(
                id: "nudge_badge_\(closest.badge.id)", kind: .nudge, emoji: closest.badge.emoji,
                title: "\(closest.remaining.formatted()) \(p.unit) from \(closest.badge.name)",
                detail: closest.badge.requirement,
                time: "Now", date: nil,
                progress: AlertProgress(current: p.current, target: p.target,
                                        unit: p.unit, tint: .green)
            ))
        }

        // Streak — gentle encouragement only, never guilt about a rest day.
        if stats.streakDays >= 2 {
            items.append(AlertItem(
                id: "nudge_streak", kind: .streak, emoji: "🔥",
                title: "\(stats.streakDays)-day streak",
                detail: "You're on a roll",
                time: "Now", date: nil
            ))
        }
        return items
    }

    // MARK: Recent events — replayed from the quest log

    private static func recent(
        quests: [Quest],
        scores: [UUID: XPBreakdown],
        now: Date,
        calendar: Calendar
    ) -> [AlertItem] {
        let sorted = quests.sorted { $0.endDate < $1.endDate }
        var events: [AlertItem] = []

        // Level-ups: accumulate XP chronologically, emit each threshold crossed.
        var cumulative = 0
        var lastLevel = LevelEngine.level(forXP: 0)
        for quest in sorted {
            cumulative += scores[quest.id]?.total ?? 0
            let level = LevelEngine.level(forXP: cumulative)
            if level > lastLevel {
                for reached in (lastLevel + 1)...level {
                    events.append(AlertItem(
                        id: "level_\(reached)", kind: .levelUp, emoji: "⬆️",
                        title: "Reached Level \(reached)",
                        detail: "You're now a \(LevelEngine.title(for: reached))",
                        time: relativeTime(quest.endDate, now: now, calendar: calendar),
                        date: quest.endDate
                    ))
                }
                lastLevel = level
            }
        }

        // Badges: replay the log to find the quest that first satisfied each one
        // (reuses BadgeCatalog so the predicates can't drift from the sheet).
        var running: [Quest] = []
        var unlocked: Set<String> = []
        for quest in sorted {
            running.append(quest)
            let earned = BadgeCatalog.all(for: running, stats: DashboardStats(quests: running)).filter(\.earned)
            for badge in earned where !unlocked.contains(badge.id) {
                unlocked.insert(badge.id)
                events.append(AlertItem(
                    id: "badge_\(badge.id)", kind: .badge, emoji: badge.emoji,
                    title: "Earned \(badge.name)",
                    detail: badge.requirement,
                    time: relativeTime(quest.endDate, now: now, calendar: calendar),
                    date: quest.endDate
                ))
            }
        }

        // Records: current all-time bests, dated to the quest that set them.
        // Heart rate is deliberately excluded — never celebrate a high BPM.
        let earned = quests.filter(\.earned)
        func name(_ quest: Quest) -> String { quest.rewardNames.first ?? quest.activityLabel.capitalized }
        if let burn = earned.max(by: { $0.calories < $1.calories }), burn.calories > 0 {
            events.append(AlertItem(
                id: "record_burn", kind: .record, emoji: "🔥",
                title: "Biggest burn", detail: "\(burn.calories.formatted()) cal · \(name(burn))",
                time: relativeTime(burn.endDate, now: now, calendar: calendar), date: burn.endDate
            ))
        }
        if let longest = earned.max(by: { $0.duration < $1.duration }), longest.duration > 0 {
            events.append(AlertItem(
                id: "record_duration", kind: .record, emoji: "⏱️",
                title: "Longest quest", detail: "\(Int(longest.duration / 60)) min · \(name(longest))",
                time: relativeTime(longest.endDate, now: now, calendar: calendar), date: longest.endDate
            ))
        }
        if let steps = earned.compactMap({ q in q.steps.map { ($0, q) } }).max(by: { $0.0 < $1.0 }), steps.0 > 0 {
            events.append(AlertItem(
                id: "record_steps", kind: .record, emoji: "👣",
                title: "Most steps", detail: "\(steps.0.formatted()) steps · \(name(steps.1))",
                time: relativeTime(steps.1.endDate, now: now, calendar: calendar), date: steps.1.endDate
            ))
        }

        return events.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private static func relativeTime(_ date: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<0:  return date.formatted(.dateTime.month(.abbreviated).day())
        case 0:     return "Today"
        case 1:     return "Yesterday"
        case 2...6: return "\(days)d ago"
        default:    return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Weekly challenge

/// One rotating challenge per calendar week. The pick is **deterministic** —
/// seeded by the week start, so the same challenge shows all week and a new one
/// appears next week — and progress is derived from that week's quests. Zero
/// stored state: reinstall rebuilds it, and there's nothing to migrate or sync.
///
/// Health guardrail (Xavier's rule): every challenge is a weekly aggregate —
/// rest days never reduce progress, and nothing here rewards raw maximum burn
/// over control.
struct WeeklyChallenge: Identifiable, Equatable {
    enum Kind: Int, CaseIterable {
        case questSpree, precisionWeek, dungeonMenu, bigBurn, longHaul
    }

    let id: String
    let kind: Kind
    let emoji: String
    let name: String
    let detail: String
    let goal: Int
    let progress: Int
    let unit: String
    let weekEnd: Date

    var fraction: Double { goal > 0 ? min(Double(progress) / Double(goal), 1) : 0 }
    var isComplete: Bool { progress >= goal }

    /// "1 quest" not "1 quests" — for nudge/notification copy.
    func unitLabel(for count: Int) -> String {
        guard count == 1 else { return unit }
        switch unit {
        case "quests":  return "quest"
        case "classes": return "class"
        default:        return unit
        }
    }

    func daysLeftText(now: Date = .now, calendar: Calendar = .current) -> String {
        let days = max(calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: weekEnd
        ).day ?? 0, 0)
        switch days {
        case ...1: return "ENDS TODAY"
        case 2:    return "1 DAY LEFT"
        default:   return "\(days - 1) DAYS LEFT"
        }
    }

    static func current(for quests: [Quest], now: Date = .now, calendar: Calendar = .current) -> WeeklyChallenge? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let weekQuests = quests.filter { week.contains($0.endDate) }
        let earned = weekQuests.filter(\.earned)

        // Same pick for the whole week, rotating weekly. `-br.demoChallengeIndex`
        // (UserDefaults argument domain) forces a specific challenge for QA.
        let weekNumber = Int(week.start.timeIntervalSince1970 / 604_800)
        let kinds = Kind.allCases
        let index: Int
        if UserDefaults.standard.object(forKey: "br.demoChallengeIndex") != nil {
            index = UserDefaults.standard.integer(forKey: "br.demoChallengeIndex") % kinds.count
        } else {
            index = weekNumber % kinds.count
        }
        let kind = kinds[index]

        func classKey(_ quest: Quest) -> String {
            CharacterClass.coreOrder.contains(quest.activityLabel) ? quest.activityLabel : "OTHER"
        }
        // Same within-goal definition as the precision badges (earned, and no
        // more than the tolerance over the goal), so systems can't disagree.
        let tolerance = GameBalance.challengePrecisionTolerance
        let preciseCount = earned.filter { quest in
            guard let goal = quest.goalCalories, goal > 0 else { return false }
            let ratio = Double(quest.calories) / Double(goal)
            return ratio >= 1 && ratio <= 1 + tolerance
        }.count

        // Goals come from GameBalance; each detail string interpolates the
        // same constant, so tuning a number can never leave stale copy behind.
        let (emoji, name, detail, goal, progress, unit): (String, String, String, Int, Int, String)
        switch kind {
        case .questSpree:
            let target = GameBalance.challengeSpreeQuests
            (emoji, name, detail, goal, progress, unit) =
                ("🗡️", "QUEST SPREE", "Complete \(target) quests this week",
                 target, earned.count, "quests")
        case .precisionWeek:
            let target = GameBalance.challengePrecisionQuests
            let pct = Int(tolerance * 100)
            (emoji, name, detail, goal, progress, unit) =
                ("🎯", "PRECISION WEEK", "Finish \(target) quests within \(pct)% of the goal",
                 target, preciseCount, "quests")
        case .dungeonMenu:
            let target = GameBalance.challengeMenuClasses
            (emoji, name, detail, goal, progress, unit) =
                ("🧭", "DUNGEON MENU", "Earn quests in \(target) different classes",
                 target, Set(earned.map(classKey)).count, "classes")
        case .bigBurn:
            let target = GameBalance.challengeBigBurnCalories
            (emoji, name, detail, goal, progress, unit) =
                ("🔥", "BIG BURN", "Burn \(target.formatted()) calories in quests this week",
                 target, weekQuests.reduce(0) { $0 + $1.calories }, "cal")
        case .longHaul:
            let target = GameBalance.challengeLongHaulMinutes
            (emoji, name, detail, goal, progress, unit) =
                ("⏳", "LONG HAUL", "Log \(target) minutes of quest time this week",
                 target, weekQuests.reduce(0) { $0 + Int($1.duration / 60) }, "min")
        }

        return WeeklyChallenge(
            id: "\(kind)_\(weekNumber)",
            kind: kind, emoji: emoji, name: name, detail: detail,
            goal: goal, progress: progress, unit: unit,
            weekEnd: week.end
        )
    }
}
