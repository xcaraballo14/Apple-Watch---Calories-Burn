import Foundation
import HealthKit
import WatchKit
import WidgetKit

enum AppPhase {
    case picking, workout, earned
}

/// Whether we can read the data we need to run a quest.
enum HealthAccess {
    case unknown      // not yet asked
    case granted      // good to go (or not-yet-determined, which still lets us prompt)
    case denied       // user said no to sharing workouts
    case unavailable  // HealthKit not present on this device
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
    @Published var heartRate: Double = 0            // live BPM (0 = no reading yet)
    @Published var elapsedSeconds: Int = 0          // workout duration
    @Published var summaryDuration: Int = 0         // frozen length once earned (s)
    @Published var summaryAvgHR: Int = 0            // average BPM over the workout
    @Published var summaryCalories: Int = 0         // total burned at the finish line
    @Published var healthAccess: HealthAccess = .unknown

    private var startDate: Date?
    private var tickTask: Task<Void, Never>?
    private var hapticQuarter = 0  // highest 25% increment already buzzed (0–4)

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let rewardIDs   = "br.activeRewardIDs"
        static let phase       = "br.phase"
        static let earnedCount = "br.earnedCount"
        static let calories    = "br.caloriesBurned"
        static let startDate   = "br.startDate"
        static let sumDuration = "br.summaryDuration"
        static let sumAvgHR    = "br.summaryAvgHR"
        static let sumCalories = "br.summaryCalories"
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
        guard HKHealthStore.isHealthDataAvailable() else {
            healthAccess = .unavailable
            return
        }
        let share: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        let read: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        do {
            try await healthStore.requestAuthorization(toShare: share, read: read)
        } catch {
            print("WorkoutManager: authorization error – \(error)")
        }
        updateHealthAccess()
    }

    /// Re-reads the current authorization without prompting. HealthKit hides *read*
    /// status for privacy, so we use the workout *share* status as a proxy: if the
    /// user denied sharing workouts, they almost certainly denied calories too.
    func updateHealthAccess() {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthAccess = .unavailable
            return
        }
        switch healthStore.authorizationStatus(for: HKWorkoutType.workoutType()) {
        case .sharingDenied: healthAccess = .denied
        default:             healthAccess = .granted  // authorized or notDetermined
        }
    }

    func startWorkout(for rewards: [Reward], type: WorkoutType = .other) {
        selectedRewards = rewards.sorted { $0.calories < $1.calories }
        caloriesBurned = 0
        earnedCount = 0
        milestoneFlash = nil
        heartRate = 0
        hapticQuarter = 0
        summaryDuration = 0
        summaryAvgHR = 0
        summaryCalories = 0
        startDate = Date()
        elapsedSeconds = 0
        startTicking()

        let config = HKWorkoutConfiguration()
        config.activityType = type.activityType
        config.locationType = type.locationType

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
        heartRate = 0
        elapsedSeconds = 0
        summaryDuration = 0
        summaryAvgHR = 0
        summaryCalories = 0
        startDate = nil
        hapticQuarter = 0
        stopTicking()
        clearState()
    }

    /// Freeze the workout summary, then end the session and save the HKWorkout to Health.
    /// Called once the final reward is earned (the session is left running until this point
    /// so the builder's statistics cover the whole effort).
    private func finishAndSaveWorkout() {
        summaryDuration = elapsedSeconds
        summaryCalories = Int(caloriesBurned)

        let hrType = HKQuantityType(.heartRate)
        if let avgHR = builder?.statistics(for: hrType)?
            .averageQuantity()?
            .doubleValue(for: .count().unitDivided(by: .minute())) {
            summaryAvgHR = Int(avgHR)
        } else if heartRate > 0 {
            summaryAvgHR = Int(heartRate)  // fallback when no aggregate is available
        }

        // Detach the session/builder up front so a later newGoal() can't double-end them.
        let session = self.session
        let builder = self.builder
        self.session = nil
        self.builder = nil

        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            builder?.finishWorkout { _, _ in }
        }
    }

    func checkMilestones(cal: Double) {
        caloriesBurned = cal

        // Subtle haptic pulses at 25 / 50 / 75 % progress (quarter < 4 so we don't double-buzz at 100%)
        let quarter = Int(progress * 4)
        if quarter > hapticQuarter && quarter < 4 {
            for _ in hapticQuarter..<quarter {
                WKInterfaceDevice.current().play(.click)
            }
            hapticQuarter = quarter
        }

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
                stopTicking()
                WKInterfaceDevice.current().play(.success)
                finishAndSaveWorkout()
            }
        }
        persistState()
    }

    // MARK: - Elapsed-time ticker

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                if let start = self?.startDate {
                    self?.elapsedSeconds = Int(Date().timeIntervalSince(start))
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
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
        if let startDate {
            defaults.set(startDate.timeIntervalSinceReferenceDate, forKey: Keys.startDate)
        }
        defaults.set(summaryDuration, forKey: Keys.sumDuration)
        defaults.set(summaryAvgHR, forKey: Keys.sumAvgHR)
        defaults.set(summaryCalories, forKey: Keys.sumCalories)
        publishSnapshot()
    }

    private func clearState() {
        [Keys.rewardIDs, Keys.phase, Keys.earnedCount, Keys.calories, Keys.startDate,
         Keys.sumDuration, Keys.sumAvgHR, Keys.sumCalories]
            .forEach { defaults.removeObject(forKey: $0) }
        publishSnapshot()
    }

    /// Mirror the current goal into the shared App Group and refresh the complication.
    private func publishSnapshot() {
        let snapshot = BurnRewardSnapshot(
            isActive: phase == .workout,
            emoji: selectedRewards.first?.emoji ?? "🔥",
            caloriesBurned: Int(caloriesBurned),
            totalGoal: totalGoal
        )
        BurnRewardShared.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
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
        summaryDuration = defaults.integer(forKey: Keys.sumDuration)
        summaryAvgHR    = defaults.integer(forKey: Keys.sumAvgHR)
        summaryCalories = defaults.integer(forKey: Keys.sumCalories)

        let savedStart = defaults.double(forKey: Keys.startDate)
        if savedStart > 0 {
            startDate = Date(timeIntervalSinceReferenceDate: savedStart)
            // Once earned the clock is frozen; while working out it keeps ticking.
            elapsedSeconds = phase == .workout
                ? Int(Date().timeIntervalSince(startDate!))
                : summaryDuration
        }

        // Reconnect to a workout session that may still be running in the background.
        if phase == .workout {
            startTicking()
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
        heartRate = Double(Int.random(in: 120...160))  // fake BPM for Simulator
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
        let energyType = HKQuantityType(.activeEnergyBurned)
        let hrType     = HKQuantityType(.heartRate)

        let cal = collectedTypes.contains(energyType)
            ? workoutBuilder.statistics(for: energyType)?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            : nil

        let bpm = collectedTypes.contains(hrType)
            ? workoutBuilder.statistics(for: hrType)?
                .mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute()))
            : nil

        Task { @MainActor [weak self] in
            guard let self, self.phase == .workout else { return }
            if let bpm { self.heartRate = bpm }
            if let cal { self.checkMilestones(cal: cal) }
        }
    }
}
