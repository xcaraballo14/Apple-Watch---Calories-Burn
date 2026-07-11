import Foundation
import HealthKit

/// Read-only gateway to the workouts the watch app saved. The iPhone app never
/// writes health data — HealthKit is queried fresh on every refresh, which is
/// what makes the quest history and level impossible to desync.
final class HealthKitService {
    /// Matches both the watch app (`…app.watchkitapp`) and any future source
    /// under the same family.
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
        ]
        try await store.requestAuthorization(toShare: [], read: read)
        defaults.set(true, forKey: Self.didRequestAuthKey)
    }

    /// All BurnReward workouts, newest first.
    func fetchQuests() async throws -> [Quest] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout()],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: nil
        )
        let workouts = try await descriptor.result(for: store)
        return workouts
            .filter {
                $0.sourceRevision.source.bundleIdentifier
                    .hasPrefix(Self.sourceBundlePrefix)
            }
            .map(Quest.init(workout:))
    }
}
