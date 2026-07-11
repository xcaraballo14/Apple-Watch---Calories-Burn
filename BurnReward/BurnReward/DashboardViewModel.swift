import Combine
import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded
        case unavailable   // HealthKit not present (e.g. iPad) — shouldn't happen on iPhone
        case failed        // a read actually threw — distinct from a genuinely empty account
    }

    @Published private(set) var quests: [Quest] = []
    @Published private(set) var state: LoadState = .idle

    /// Cached derivations of `quests`, kept in lockstep by `setQuests`. History
    /// rows read `scores[id]` in a loop and the character sheet reads `stats`
    /// repeatedly, so recomputing either per render (~1/s during a live quest)
    /// was needless work — now they only recompute when the quest list changes.
    @Published private(set) var stats = DashboardStats(quests: [])
    @Published private(set) var scores: [UUID: XPBreakdown] = [:]

    /// Badge unlocks + record breaks from the latest refresh, oldest first —
    /// the toast overlay shows the head and pops via `dismissCelebration()`.
    @Published private(set) var celebrations: [Celebration] = []

    /// Cached personal records (like `stats`/`scores`) — the character sheet
    /// reads the list and History rows look up record-holder stamps.
    @Published private(set) var records: [PersonalRecord] = []

    /// The bell feed, rebuilt with the quest list: forward-looking nudges +
    /// a replayed history of achievement events. Derived, no backend.
    @Published private(set) var alertNudges: [AlertItem] = []
    @Published private(set) var alertRecent: [AlertItem] = []

    /// This week's rotating challenge — deterministic pick, derived progress.
    @Published private(set) var weeklyChallenge: WeeklyChallenge?

    /// When the alerts sheet was last opened — an event newer than this is
    /// "unread" (drives both the bell dot and the per-row dot). Seeded to now
    /// on first real load so pre-existing history never lights the bell.
    @Published private(set) var alertsLastSeen: Date = {
        let t = UserDefaults.standard.double(forKey: alertsSeenKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : .distantPast
    }()
    private static let alertsSeenKey = "br.ios.alertsLastSeen"

    private let health = HealthKitService()

    /// Badge IDs the player has already been congratulated for. Not game state —
    /// badges stay derived from HealthKit — just a "seen" cache so we only toast
    /// *new* unlocks. Absent key = first observation: seed silently, so neither
    /// a reinstall nor this feature landing on an existing history fires a
    /// barrage of back-dated toasts.
    private static let seenBadgesKey = "br.ios.seenBadgeIDs"

    /// `-BRSampleData` launch argument fills the app with demo quests — used
    /// for simulator screenshots, where HealthKit has no real workout data.
    private var useSampleData: Bool {
        ProcessInfo.processInfo.arguments.contains("-BRSampleData")
    }

    init(sample: Bool = false) {
        if sample {
            setQuests(Self.sampleQuests())
            state = .loaded
        }
        // `-BRDemoBadgeToast` queues one fake badge + one fake record at launch
        // so both toast styles can be screenshotted without earning them.
        if ProcessInfo.processInfo.arguments.contains("-BRDemoBadgeToast") {
            celebrations = [
                Celebration(id: "demo_pr", kind: .record, emoji: "🔥",
                            headline: "NEW RECORD!", title: "BIGGEST BURN · 812 CAL",
                            detail: "Pizza Slice · beats 700 cal"),
                Celebration(badge: Badge(
                    id: "dragon_slayer", emoji: "🐉", name: "Dragon Slayer",
                    requirement: "Burn 1,000+ calories in one quest", earned: true,
                    progress: .init(current: 1042, target: 1000, unit: "cal")
                )),
            ]
        }
    }

    var lastQuest: Quest? { quests.first }

    /// The most recent quests, including the one spotlighted in the hero card,
    /// so the log always matches the top of the History tab exactly.
    var recentQuests: [Quest] { Array(quests.prefix(3)) }

    /// The one funnel for replacing the quest list. Recomputing the derived
    /// `stats` / `scores` here (not on each read) keeps them from ever going
    /// stale against `quests` while sparing every render the recompute.
    private func setQuests(_ newQuests: [Quest]) {
        quests = newQuests
        stats = DashboardStats(quests: newQuests)
        scores = XPEngine.scoreAll(newQuests)
        records = PersonalRecord.all(for: newQuests)
        let feed = AlertFeed.build(quests: newQuests, scores: scores, stats: stats)
        alertNudges = feed.nudges
        alertRecent = feed.recent
        weeklyChallenge = WeeklyChallenge.current(for: newQuests)
        detectBadgeUnlocks()
        detectRecordBreaks()
        detectLevelUp()
        rescheduleStreakReminder()
        rescheduleChallengeReminder()
    }

    // MARK: - Local notifications (C6 push half)

    private var earnedToday: Bool {
        let calendar = Calendar.current
        return quests.contains { $0.earned && calendar.isDateInToday($0.endDate) }
    }

    /// Re-plans the evening streak reminder from the current state. Also called
    /// by Settings when the channel or time changes.
    func rescheduleStreakReminder() {
        NotificationService.shared.rescheduleStreakReminder(
            streakDays: stats.streakDays,
            earnedToday: earnedToday
        )
    }

    /// Re-plans the end-of-week challenge heads-up. Also called by Settings.
    func rescheduleChallengeReminder() {
        NotificationService.shared.rescheduleChallengeReminder(weeklyChallenge)
    }

    /// Same seed-silently pattern as badges: the first observation records the
    /// current level without celebrating, so installs/reinstalls stay quiet.
    private static let notifiedLevelKey = "br.ios.notifiedLevel"
    private func detectLevelUp() {
        let level = stats.levelProgress.level
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.notifiedLevelKey) != nil else {
            defaults.set(level, forKey: Self.notifiedLevelKey)
            return
        }
        let last = defaults.integer(forKey: Self.notifiedLevelKey)
        guard level != last else { return }
        defaults.set(level, forKey: Self.notifiedLevelKey)
        // Level can drop if workouts are deleted in Health — resync silently.
        if level > last {
            NotificationService.shared.postLevelUp(
                level: level, title: LevelEngine.title(for: level)
            )
        }
    }

    // MARK: - Alerts (bell)

    /// True when any achievement event is newer than the last time the sheet
    /// was opened — drives the header bell's red dot.
    var hasUnreadAlerts: Bool {
        alertRecent.contains { ($0.date ?? .distantPast) > alertsLastSeen }
    }

    func isUnread(_ item: AlertItem) -> Bool {
        guard let date = item.date else { return false }
        return date > alertsLastSeen
    }

    /// Called when the alerts sheet closes — everything shown is now "seen".
    func markAlertsSeen() {
        let seen = Date.now
        alertsLastSeen = seen
        UserDefaults.standard.set(seen.timeIntervalSince1970, forKey: Self.alertsSeenKey)
    }

    /// Diffs the earned badge set against the persisted "seen" list and queues
    /// celebrations for genuinely new unlocks. Only called from `setQuests`,
    /// which only ever carries a real fetch result — so seeding can't race an
    /// interim empty state.
    private func detectBadgeUnlocks() {
        let badges = BadgeCatalog.all(for: quests, stats: stats)
        let earnedNow = badges.filter(\.earned)
        let earnedIDs = Set(earnedNow.map(\.id))
        let defaults = UserDefaults.standard

        guard let seenArray = defaults.stringArray(forKey: Self.seenBadgesKey) else {
            defaults.set(earnedIDs.sorted(), forKey: Self.seenBadgesKey)   // first observation: seed silently
            return
        }
        let seen = Set(seenArray)
        // Catalog order (not set order) keeps multi-unlock toasts in ladder order.
        let fresh = earnedNow.filter { !seen.contains($0.id) }
        guard !fresh.isEmpty else { return }
        celebrations.append(contentsOf: fresh.map(Celebration.init(badge:)))
        defaults.set(seen.union(earnedIDs).sorted(), forKey: Self.seenBadgesKey)
        // Backgrounded (e.g. quest-end mirroring launch): the lock screen gets
        // the news; the service no-ops while the app is active so the in-app
        // toast never doubles up.
        NotificationService.shared.postBadgeUnlocks(fresh)
    }

    /// Personal-record breaks (burn / duration / steps — heart rate and streak
    /// deliberately excluded). Same pattern as badges: persisted bests, diffed
    /// on every refresh, seeded silently on first observation so installs and
    /// reinstalls never back-date a celebration. Shrinks (workouts deleted in
    /// Health) resync silently.
    private enum PRKeys {
        static let burn = "br.ios.prBurn"
        static let duration = "br.ios.prDuration"   // seconds
        static let steps = "br.ios.prSteps"
    }

    private func detectRecordBreaks() {
        let defaults = UserDefaults.standard
        let earned = quests.filter(\.earned)
        func name(_ quest: Quest) -> String {
            quest.rewardNames.first ?? quest.activityLabel.capitalized
        }
        let bestBurn = earned.max { $0.calories < $1.calories }
        let bestDuration = earned.max { $0.duration < $1.duration }
        let bestSteps = earned.compactMap { q in q.steps.map { (q, $0) } }.max { $0.1 < $1.1 }

        guard defaults.object(forKey: PRKeys.burn) != nil else {
            defaults.set(bestBurn?.calories ?? 0, forKey: PRKeys.burn)
            defaults.set(Int(bestDuration?.duration ?? 0), forKey: PRKeys.duration)
            defaults.set(bestSteps?.1 ?? 0, forKey: PRKeys.steps)
            return
        }

        func check(
            key: String, newValue: Int, quest: Quest?,
            emoji: String, label: String,
            format: (Int) -> String
        ) {
            let stored = defaults.integer(forKey: key)
            guard newValue != stored else { return }
            defaults.set(newValue, forKey: key)
            guard newValue > stored, stored > 0, let quest else { return }   // shrink → silent resync; first-ever value isn't a "break"
            let celebration = Celebration(
                id: "pr_\(key)_\(newValue)", kind: .record, emoji: emoji,
                headline: "NEW RECORD!",
                title: "\(label) · \(format(newValue))",
                detail: "\(name(quest)) · beats \(format(stored))"
            )
            celebrations.append(celebration)
            NotificationService.shared.postRecordBreak(
                id: celebration.id,
                title: "New record \(emoji)",
                body: "\(label.capitalized): \(format(newValue)) · \(name(quest))"
            )
        }

        check(key: PRKeys.burn, newValue: bestBurn?.calories ?? 0, quest: bestBurn,
              emoji: "🔥", label: "BIGGEST BURN") { "\($0.formatted()) cal" }
        check(key: PRKeys.duration, newValue: Int(bestDuration?.duration ?? 0), quest: bestDuration,
              emoji: "⏱️", label: "LONGEST QUEST") { BRFormat.duration(TimeInterval($0)) }
        check(key: PRKeys.steps, newValue: bestSteps?.1 ?? 0, quest: bestSteps?.0,
              emoji: "👣", label: "MOST STEPS") { "\($0.formatted()) steps" }
    }

    /// Record kinds this quest currently holds — drives the gold stamps in
    /// History rows and the quest detail. Only the celebrated kinds.
    func recordKinds(for quest: Quest) -> [PersonalRecord.Kind] {
        records
            .filter { $0.quest?.id == quest.id }
            .map(\.kind)
            .filter { $0 == .burn || $0 == .duration || $0 == .steps }
    }

    /// Pops the toast currently showing; the overlay then shows the next queued.
    func dismissCelebration() {
        guard !celebrations.isEmpty else { return }
        celebrations.removeFirst()
    }

    func xpBreakdown(for quest: Quest) -> XPBreakdown {
        scores[quest.id] ?? XPEngine.score(quest, isFirstQuestOfDay: false)
    }

    struct WeekBucket: Identifiable {
        let id: Date        // start of the calendar week
        let calories: Int
    }

    /// Calories per week for the History chart — the last 8 calendar weeks,
    /// oldest first, including empty weeks so gaps stay visible.
    var weeklyBuckets: [WeekBucket] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        var totals: [Date: Int] = [:]
        for quest in quests {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: quest.endDate)?.start else { continue }
            totals[week, default: 0] += quest.calories
        }
        return (0..<8).reversed().compactMap { offset in
            guard let week = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek) else { return nil }
            return WeekBucket(id: week, calories: totals[week] ?? 0)
        }
    }

    func refresh() async {
        if useSampleData {
            setQuests(Self.sampleQuests())
            state = .loaded
            return
        }
        guard health.isAvailable else {
            state = .unavailable
            return
        }
        if quests.isEmpty { state = .loading }
        do {
            try await health.requestReadAuthorization()
            setQuests(try await health.fetchQuests())
            // First real load on an existing history: mark it all seen so the
            // bell doesn't light up for back-dated events the user never missed.
            if UserDefaults.standard.object(forKey: Self.alertsSeenKey) == nil {
                markAlertsSeen()
            }
            state = .loaded
        } catch {
            // A thrown read is a real operation failure, not merely an empty
            // account — a *denied* read returns [] without throwing. Keep any
            // quests we already had; only surface the failure hint when there's
            // nothing to show, so a transient error doesn't look like "no quests."
            state = quests.isEmpty ? .failed : .loaded
        }
    }

    // MARK: - Sample data (previews + simulator screenshots)

    static func sampleQuests(now: Date = .now) -> [Quest] {
        let cal = Calendar.current

        func quest(
            daysAgo: Int,
            hour: Int,
            minutes: Double,
            calories: Int,
            hr: Int,
            type: String,
            names: [String],
            emojis: [String],
            goal: Int,
            earned: Bool = true
        ) -> Quest {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: now)) ?? now
            let start = cal.date(byAdding: .hour, value: hour, to: day) ?? day
            let end = start.addingTimeInterval(minutes * 60)
            // Plausible cadence for step-based activities; nil where steps aren't
            // meaningful (bike/lift), so the sample mirrors real workout data.
            let stepsPerMinute: Double? = switch type {
            case "RUN":  160
            case "WALK": 110
            default:     nil
            }
            return Quest(
                id: UUID(), startDate: start, endDate: end,
                duration: minutes * 60, calories: calories, averageHeartRate: hr,
                steps: stepsPerMinute.map { Int($0 * minutes) },
                activityLabel: type, rewardNames: names, rewardEmojis: emojis,
                goalCalories: goal, earned: earned, isLegacy: false
            )
        }

        return [
            quest(daysAgo: 0, hour: 7, minutes: 28.7, calories: 412, hr: 142, type: "RUN",
                  names: ["Pizza Slice"], emojis: ["🍕"], goal: 400),
            quest(daysAgo: 3, hour: 18, minutes: 52, calories: 282, hr: 118, type: "WALK",
                  names: ["Donut"], emojis: ["🍩"], goal: 270),
            quest(daysAgo: 4, hour: 9, minutes: 24, calories: 195, hr: 136, type: "RUN",
                  names: ["Taco"], emojis: ["🌮"], goal: 180),
            quest(daysAgo: 6, hour: 17, minutes: 40, calories: 338, hr: 124, type: "BIKE",
                  names: ["Bubble Tea (Boba)"], emojis: ["🧋"], goal: 330),
            quest(daysAgo: 8, hour: 8, minutes: 61, calories: 540, hr: 131, type: "RUN",
                  names: ["Cheeseburger"], emojis: ["🍔"], goal: 550, earned: false),
            quest(daysAgo: 9, hour: 19, minutes: 35, calories: 265, hr: 121, type: "WALK",
                  names: ["Brownie"], emojis: ["🍫"], goal: 250),
            quest(daysAgo: 11, hour: 7, minutes: 47, calories: 401, hr: 138, type: "RUN",
                  names: ["Pizza Slice"], emojis: ["🍕"], goal: 400),
            quest(daysAgo: 13, hour: 18, minutes: 55, calories: 425, hr: 127, type: "LIFT",
                  names: ["Mac & Cheese Bowl"], emojis: ["🧀"], goal: 420),
            quest(daysAgo: 15, hour: 10, minutes: 33, calories: 245, hr: 133, type: "RUN",
                  names: ["Soda (20 oz)"], emojis: ["🥤"], goal: 240),
            quest(daysAgo: 17, hour: 8, minutes: 75, calories: 700, hr: 129, type: "BIKE",
                  names: ["Cookie", "Milkshake"], emojis: ["🍪", "🥛"], goal: 680),
            quest(daysAgo: 20, hour: 12, minutes: 26, calories: 190, hr: 140, type: "RUN",
                  names: ["Taco"], emojis: ["🌮"], goal: 180),
            quest(daysAgo: 22, hour: 17, minutes: 44, calories: 310, hr: 122, type: "WALK",
                  names: ["Cupcake"], emojis: ["🧁"], goal: 300),
        ]
    }
}
