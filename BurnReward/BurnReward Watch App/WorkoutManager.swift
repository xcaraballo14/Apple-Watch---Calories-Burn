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
    @Published var selectedRewards: [Reward] = []   // sorted ascending by calories
    @Published var caloriesBurned: Double = 0
    @Published var earnedCount: Int = 0             // milestones cleared so far
    @Published var milestoneFlash: Reward? = nil    // set briefly on intermediate earn

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let rewardIDs   = "br.activeRewardIDs"
        static let phase       = "br.phase"
        static let earnedCount = "br.earnedCount"
        static let calories    = "br.caloriesBurned"
    }

    override init() {
        super.init()
        restoreState()
    }

    var totalGoal: Int { selectedRewards.reduce(0) { $0 + $1.calories } }

    var progress: Double {
        guard totalGoal > 0 else { return 0 }
        return min(caloriesBurned / Double(totalGoal), 1.0)
    }

    var caloriesLeft: Int { max(totalGoal - Int(caloriesBurned), 0) }

    // Cumulative calorie threshold for each reward in order
    func cumulativeTarget(at index: Int) -> Int {
        selectedRewards[0...index].reduce(0) { $0 + $1.calories }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        let read: Set<HKObjectType> = [HKQuantityType(.activeEnergyBurned)]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
    }

    func startWorkout(for rewards: [Reward]) {
        selectedRewards = rewards.sorted { $0.calories < $1.calories }
        caloriesBurned = 0
        earnedCount = 0
        milestoneFlash = nil

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
        persistState()
    }

    func newGoal() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.builder?.finishWorkout { _, _ in }
        }
        phase = .picking
        selectedRewards = []
        caloriesBurned = 0
        earnedCount = 0
        milestoneFlash = nil
        clearState()
    }

    func checkMilestones(cal: Double) {
        caloriesBurned = cal
        while earnedCount < selectedRewards.count {
            let threshold = Double(cumulativeTarget(at: earnedCount))
            guard cal >= threshold else { break }
            earnedCount += 1
            if earnedCount < selectedRewards.count {
                // Intermediate milestone — flash then keep going
                let justEarned = selectedRewards[earnedCount - 1]
                WKInterfaceDevice.current().play(.notification)
                milestoneFlash = justEarned
                Task {
                    try? await Task.sleep(for: .milliseconds(1200))
                    milestoneFlash = nil
                }
            } else {
                // All rewards earned
                phase = .earned
                WKInterfaceDevice.current().play(.success)
            }
        }
        persistState()
    }

    // MARK: - Persistence

    private func persistState() {
        guard phase != .picking, !selectedRewards.isEmpty else {
            clearState()
            return
        }
        defaults.set(selectedRewards.map(\.id), forKey: Keys.rewardIDs)
        defaults.set(phase == .earned ? "earned" : "workout", forKey: Keys.phase)
        defaults.set(earnedCount, forKey: Keys.earnedCount)
        defaults.set(caloriesBurned, forKey: Keys.calories)
    }

    private func clearState() {
        [Keys.rewardIDs, Keys.phase, Keys.earnedCount, Keys.calories]
            .forEach { defaults.removeObject(forKey: $0) }
    }

    private func restoreState() {
        guard
            let ids = defaults.array(forKey: Keys.rewardIDs) as? [String],
            !ids.isEmpty
        else { return }

        let rewards = ids.compactMap { id in allRewards.first { $0.id == id } }
        guard !rewards.isEmpty else { clearState(); return }

        selectedRewards = rewards.sorted { $0.calories < $1.calories }
        caloriesBurned  = defaults.double(forKey: Keys.calories)
        earnedCount     = defaults.integer(forKey: Keys.earnedCount)
        phase           = defaults.string(forKey: Keys.phase) == "earned" ? .earned : .workout

        // Reconnect to a workout session that may still be running in the background.
        if phase == .workout {
            recoverWorkoutSession()
        }
    }

    private func recoverWorkoutSession() {
        healthStore.recoverActiveWorkoutSession { [weak self] session, _ in
            guard let self, let session else { return }
            Task { @MainActor in
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(
                    healthStore: self.healthStore,
                    workoutConfiguration: session.workoutConfiguration
                )
                session.delegate = self
                builder.delegate = self
                self.session = session
                self.builder = builder
            }
        }
    }

    // MARK: - Debug helpers

    #if DEBUG
    func simulateBurn(_ amount: Double = 50) {
        guard phase == .workout else { return }
        checkMilestones(cal: caloriesBurned + amount)
    }
    #endif
}

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
            self.checkMilestones(cal: cal)
        }
    }
}
