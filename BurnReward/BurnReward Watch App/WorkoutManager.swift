import Foundation
import HealthKit
import WatchKit

enum AppPhase {
    case picking, workout, earned
}

@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published var phase: AppPhase = .picking
    @Published var selectedReward: Reward?
    @Published var caloriesBurned: Double = 0

    var progress: Double {
        guard let goal = selectedReward?.calories, goal > 0 else { return 0 }
        return min(caloriesBurned / Double(goal), 1.0)
    }

    var caloriesLeft: Int {
        let left = (selectedReward?.calories ?? 0) - Int(caloriesBurned)
        return max(left, 0)
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.activeEnergyBurned)]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
    }

    func startWorkout(for reward: Reward) {
        selectedReward = reward
        caloriesBurned = 0

        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { _, _ in }
            phase = .workout
        } catch {
            print("WorkoutManager: failed to start session – \(error)")
            #if DEBUG
            phase = .workout
            #endif
        }
    }

    func newGoal() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        phase = .picking
        selectedReward = nil
        caloriesBurned = 0
    }
}

// MARK: - Debug helpers

#if DEBUG
    func simulateBurn(_ amount: Double = 50) {
        guard phase == .workout else { return }
        caloriesBurned += amount
        if let goal = selectedReward?.calories, caloriesBurned >= Double(goal) {
            phase = .earned
            WKInterfaceDevice.current().play(.success)
        }
    }
#endif

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ session: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ session: HKWorkoutSession, didFailWithError error: Error) {
        print("WorkoutManager: session error – \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        guard collectedTypes.contains(HKQuantityType(.activeEnergyBurned)) else { return }

        let cal = workoutBuilder
            .statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie()) ?? 0

        Task { @MainActor [weak self] in
            guard let self, self.phase == .workout else { return }
            self.caloriesBurned = cal
            if let goal = self.selectedReward?.calories, cal >= Double(goal) {
                self.phase = .earned
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
}
