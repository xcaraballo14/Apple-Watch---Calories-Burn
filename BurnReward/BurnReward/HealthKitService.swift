import Foundation
import HealthKit

/// Read-only gateway to the player's workout history. The iPhone app never
/// writes health data — HealthKit is queried fresh on every refresh, which is
/// what makes the quest history and level impossible to desync.
final class HealthKitService {
    /// Identifies BurnReward's own workouts (`…app.watchkitapp` and any future
    /// source under the same family). No longer a *filter* — see `fetchQuests()`
    /// — but still how a quest is told apart from an outside workout.
    static let sourceBundlePrefix = "com.burnrewardapp.app"

    private let store = HKHealthStore()
    private let defaults = UserDefaults.standard
    private static let didRequestAuthKey = "br.ios.didRequestHealthAuth"

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestReadAuthorization() async throws {
        // Present the system sheet at most once per install. For read-only
        // requests HealthKit never confirms the grant (privacy), so
        // statusForAuthorizationRequest returns .shouldRequest indefinitely and
        // the every-refresh call path re-raised the sheet forever. A persisted
        // "already asked" flag is the only reliable one-shot signal.
        guard !defaults.bool(forKey: Self.didRequestAuthKey) else { return }
        let read: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),   // the quest detail's Steps row
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
        ]
        try await store.requestAuthorization(toShare: [], read: read)
        defaults.set(true, forKey: Self.didRequestAuthKey)
    }

    /// Every workout in Apple Health, newest first, overlapping duplicates removed.
    ///
    /// This used to filter to BurnReward's own bundle id, which meant the app was
    /// blind to Strava, Garmin, a ring, a phone-tracked session, and even Apple's
    /// own Workout app — the root cause of the 2026-07-28 "no real retention"
    /// tester round (`LAUNCH_SCOPE.md`). Opening it is the launch headline.
    func fetchQuests() async throws -> [Quest] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout()],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: nil
        )
        let workouts = try await descriptor.result(for: store)
        return Self.deduplicate(workouts.map(Quest.init(workout:)))
    }

    /// Collapses the same session recorded by two apps into one quest.
    ///
    /// Wearing an Apple Watch while Strava records the same run writes two
    /// HKWorkouts, and counting both would double a player's XP for one effort.
    /// Two workouts are treated as the same session when they overlap for more
    /// than half of the shorter one — loose enough to catch apps that start and
    /// stop a few seconds apart, tight enough that back-to-back sessions and a
    /// walk during a long ride stay separate.
    ///
    /// Deterministic by construction: the input is sorted by (start, id) before
    /// anything is compared, and every tie-break ends at the id. That matters
    /// more than it looks — the whole architecture rests on a reinstall
    /// re-deriving byte-identical state from the same HealthKit history, so a
    /// dedup that depended on fetch order would quietly break levels.
    static func deduplicate(_ quests: [Quest]) -> [Quest] {
        let ordered = quests.sorted {
            ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString)
        }

        var kept: [Quest] = []
        kept.reserveCapacity(ordered.count)

        for quest in ordered {
            // Only the tail can overlap: input is start-sorted, so once a kept
            // workout ends before this one starts, nothing earlier can match.
            if let index = kept.lastIndex(where: { overlaps($0, quest) }) {
                if preferred(quest, over: kept[index]) { kept[index] = quest }
            } else {
                kept.append(quest)
            }
        }

        return kept.sorted {
            ($0.endDate, $0.id.uuidString) > ($1.endDate, $1.id.uuidString)
        }
    }

    private static func overlaps(_ a: Quest, _ b: Quest) -> Bool {
        let start = max(a.startDate, b.startDate)
        let end = min(a.endDate, b.endDate)
        let shared = end.timeIntervalSince(start)
        guard shared > 0 else { return false }
        let shorter = min(a.duration, b.duration)
        guard shorter > 0 else { return false }
        return shared / shorter > 0.5
    }

    /// Which recording of the same session survives.
    ///
    /// BurnReward's own always wins: it is the one carrying the reward metadata,
    /// so letting a third-party copy displace it would strip the quest of its
    /// reward and its EARNED state. After that, prefer the richer record — heart
    /// rate drives the intensity factor, distance is worth showing — then the
    /// longer one, then the id so the result never depends on order.
    private static func preferred(_ candidate: Quest, over incumbent: Quest) -> Bool {
        if candidate.isOutside != incumbent.isOutside { return !candidate.isOutside }

        let candidateRichness = richness(candidate)
        let incumbentRichness = richness(incumbent)
        if candidateRichness != incumbentRichness {
            return candidateRichness > incumbentRichness
        }
        if candidate.duration != incumbent.duration {
            return candidate.duration > incumbent.duration
        }
        return candidate.id.uuidString > incumbent.id.uuidString
    }

    private static func richness(_ quest: Quest) -> Int {
        var score = 0
        if quest.averageHeartRate != nil { score += 2 }
        if quest.distanceMeters != nil { score += 1 }
        if quest.steps != nil { score += 1 }
        if quest.calories > 0 { score += 1 }
        return score
    }
}
