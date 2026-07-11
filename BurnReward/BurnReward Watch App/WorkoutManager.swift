import Foundation
import Combine
import HealthKit
import WatchKit
import WidgetKit

enum AppPhase {
    case picking, workout, earned
}

/// Whether the hardware can run a quest at all. Note there's deliberately no
/// `.denied` case: HealthKit never tells us reliably whether the user granted
/// *read* access (it hides that for privacy), and the workout *share* status we
/// used as a proxy was caught reporting "denied" right after a quest saved with
/// full data — impossible if access were really off. So we never predict denial;
/// a genuinely broken permission surfaces as a live quest that collects nothing
/// (`showNoDataHint` + the loud session-error paths), which is the only signal
/// HealthKit reports honestly.
enum HealthAccess {
    case unknown      // not yet asked
    case granted      // HealthKit is available — let the quest run
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
    @Published var steps: Int = 0                   // steps taken during this workout
    @Published var elapsedSeconds: Int = 0          // workout duration
    @Published var summaryDuration: Int = 0         // frozen length once earned (s)
    @Published var summaryAvgHR: Int = 0            // average BPM over the workout
    @Published var summaryCalories: Int = 0         // total burned at the finish line
    @Published var healthAccess: HealthAccess = .unknown
    @Published var sessionError: String? = nil      // live-session failure, surfaced in the UI
    @Published var receivedFirstSample = false      // true once any live metric has arrived

    private var startDate: Date?
    private var sessionAttachedAt: Date?            // when we attached to a live session
    private var tickTask: Task<Void, Never>?
    private var hapticQuarter = 0  // highest 25% increment already buzzed (0–4)
    private var lastMirrorSend = Date.distantPast  // throttles live snapshots to the phone

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
        static let didRequestAuth = "br.didRequestHealthAuth"
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

    /// The session has been live for a while but HealthKit has delivered nothing —
    /// the signature of read access being switched off (which raises no error).
    var showNoDataHint: Bool {
        guard phase == .workout, sessionError == nil, !receivedFirstSample,
              let attached = sessionAttachedAt else { return false }
        return Date().timeIntervalSince(attached) >= 45
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthAccess = .unavailable
            return
        }
        // Present the system sheet at most once per install. HealthKit hides
        // whether *read* access was granted (privacy — so an app can't infer
        // your health status), which means statusForAuthorizationRequest keeps
        // reporting .shouldRequest for our read types forever. Gating on it
        // therefore re-raised the sheet on every picker appearance and after
        // every finished quest. A persisted "already asked" flag is the only
        // signal HealthKit reports reliably.
        guard !defaults.bool(forKey: Keys.didRequestAuth) else {
            updateHealthAccess()
            return
        }
        let share: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        let read: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
        ]
        do {
            try await healthStore.requestAuthorization(toShare: share, read: read)
            defaults.set(true, forKey: Keys.didRequestAuth)
        } catch {
            print("WorkoutManager: authorization error – \(error)")
        }
        updateHealthAccess()
    }

    /// Reflects only whether HealthKit exists on this device. We deliberately do
    /// NOT read `authorizationStatus` here: on device (2026-07-08) it returned
    /// `.sharingDenied` minutes after a quest saved with full live data —
    /// impossible if access were really off — so any UI driven by it cries wolf.
    /// Real permission problems show up as a quest that collects nothing.
    func updateHealthAccess() {
        healthAccess = HKHealthStore.isHealthDataAvailable() ? .granted : .unavailable
    }

    func startWorkout(for rewards: [Reward], type: WorkoutType = .other) async {
        // Settle authorization before collection begins — the live data source only
        // collects types that are determined when collection starts, so a pending
        // sheet would mean an entire quest with zero data.
        await requestAuthorization()
        sessionError = nil
        receivedFirstSample = false
        selectedRewards = rewards.sorted { $0.calories < $1.calories }
        caloriesBurned = 0
        earnedCount = 0
        milestoneFlash = nil
        heartRate = 0
        steps = 0
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
            let dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )
            dataSource.enableCollection(for: HKQuantityType(.stepCount), predicate: nil)
            builder.dataSource = dataSource
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            session.startActivity(with: Date())
            // Show the workout screen immediately; collection starts in the
            // background. Its failure is surfaced asynchronously (red banner on
            // the workout screen) instead of gating the UI transition — the
            // awaited `beginCollection(at:)` variant can stall on device and
            // leave the button looking dead.
            sessionAttachedAt = Date()
            phase = .workout
            startMirroringToPhone(session)
            beginCollecting(with: builder)
        } catch {
            // The session itself couldn't be created — bounce back to the picker
            // with a visible reason instead of a fake, empty workout screen.
            stopTicking()
            startDate = nil
            selectedRewards = []
            sessionError = "Quest couldn't start — \(error.localizedDescription)"
            clearState()
            return
        }
        persistState()
    }

    func newGoal() {
        let session = self.session
        let builder = self.builder
        self.session = nil
        self.builder = nil

        // If a live workout is being abandoned, still stamp the quest metadata
        // (earnedCount < rewardCount marks it as unfinished for the iPhone app).
        let metadata = selectedRewards.isEmpty ? nil : questMetadata()
        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            if let metadata {
                builder?.addMetadata(metadata) { _, _ in
                    builder?.finishWorkout { _, _ in }
                }
            } else {
                builder?.finishWorkout { _, _ in }
            }
        }
        phase = .picking
        selectedRewards = []
        caloriesBurned = 0
        earnedCount = 0
        milestoneFlash = nil
        heartRate = 0
        steps = 0
        elapsedSeconds = 0
        summaryDuration = 0
        summaryAvgHR = 0
        summaryCalories = 0
        startDate = nil
        hapticQuarter = 0
        sessionError = nil
        receivedFirstSample = false
        sessionAttachedAt = nil
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

        let metadata = questMetadata()
        session?.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            builder?.addMetadata(metadata) { _, _ in
                builder?.finishWorkout { _, _ in }
            }
        }
    }

    /// Quest details attached to the workout before saving, so the iPhone app
    /// can rebuild history (reward, emoji, goal, earned-or-abandoned) straight
    /// from HealthKit with no other sync channel.
    private func questMetadata() -> [String: Any] {
        [
            QuestMetadata.schemaVersion: QuestMetadata.currentSchemaVersion,
            QuestMetadata.rewardNames: selectedRewards.map(\.name)
                .joined(separator: QuestMetadata.separator),
            QuestMetadata.rewardEmojis: selectedRewards.map(\.emoji)
                .joined(separator: QuestMetadata.separator),
            QuestMetadata.goalCalories: totalGoal,
            QuestMetadata.earnedCount: earnedCount,
            QuestMetadata.rewardCount: selectedRewards.count,
        ]
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
                sendLiveSnapshot(force: true)
                Task {
                    try? await Task.sleep(for: .milliseconds(1200))
                    milestoneFlash = nil
                }
            } else {
                // All rewards earned
                phase = .earned
                stopTicking()
                WKInterfaceDevice.current().play(.success)
                sendLiveSnapshot(force: true)
                finishAndSaveWorkout()
            }
        }
        persistState()
        sendLiveSnapshot()
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

    /// Kick off live data collection without blocking the UI. Kept synchronous so
    /// the completion-handler call doesn't trip the "use the async alternative"
    /// warning — and, deliberately, so the awaited variant can't stall the
    /// session start on device. A failure surfaces as a red banner mid-workout.
    private func beginCollecting(with builder: HKLiveWorkoutBuilder) {
        builder.beginCollection(withStart: Date()) { [weak self] success, error in
            guard !success else { return }
            let message = error?.localizedDescription ?? "HealthKit refused to start collecting."
            Task { @MainActor [weak self] in
                guard let self, self.phase == .workout else { return }
                self.sessionError = "LIVE TRACKING FAILED — \(message)"
            }
        }
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

        let catalog = RewardLibraryStore.fullCatalog()
        let rewards = ids.compactMap { id in catalog.first { $0.id == id } }
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
            // Quarters already passed shouldn't re-buzz when the first sample
            // arrives after a relaunch — resync the haptic marker to progress.
            hapticQuarter = min(Int(progress * 4), 4)
            startTicking()
            recoverWorkoutSession()
        }
    }

    private func recoverWorkoutSession() {
        healthStore.recoverActiveWorkoutSession { [weak self] session, _ in
            guard let self, let session else { return }
            Task { @MainActor in
                let builder = session.associatedWorkoutBuilder()
                let dataSource = HKLiveWorkoutDataSource(
                    healthStore: self.healthStore,
                    workoutConfiguration: session.workoutConfiguration
                )
                dataSource.enableCollection(for: HKQuantityType(.stepCount), predicate: nil)
                builder.dataSource = dataSource
                session.delegate = self
                builder.delegate = self
                self.session = session
                self.builder = builder
                self.sessionAttachedAt = Date()
                self.startMirroringToPhone(session)
            }
        }
    }

    // MARK: - Live mirroring to iPhone

    /// Mirror the running session to the companion app so it can show the
    /// quest live. Best-effort: if the phone is unreachable or the companion
    /// app isn't installed, the watch experience is unaffected.
    private func startMirroringToPhone(_ session: HKWorkoutSession) {
        session.startMirroringToCompanionDevice { _, error in
            if let error {
                print("WorkoutManager: mirroring unavailable – \(error)")
            }
        }
    }

    /// Push the current quest state over the mirrored session. Throttled to
    /// roughly one send per second; `force` bypasses the throttle (milestones,
    /// final earned state).
    private func sendLiveSnapshot(force: Bool = false) {
        guard let session, phase == .workout || force else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastMirrorSend) >= 1 else { return }
        lastMirrorSend = now

        let snapshot = LiveQuestSnapshot(
            rewardNames: selectedRewards.map(\.name),
            rewardEmojis: selectedRewards.map(\.emoji),
            goalCalories: totalGoal,
            caloriesBurned: caloriesBurned,
            heartRate: heartRate,
            earnedCount: earnedCount,
            startDate: startDate ?? now
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        session.sendToRemoteWorkoutSession(data: data) { _, _ in }
    }
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
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, self.phase == .workout else { return }
            self.sessionError = "SESSION ERROR — \(message)"
        }
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
        let stepType   = HKQuantityType(.stepCount)

        let cal = collectedTypes.contains(energyType)
            ? workoutBuilder.statistics(for: energyType)?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            : nil

        let bpm = collectedTypes.contains(hrType)
            ? workoutBuilder.statistics(for: hrType)?
                .mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute()))
            : nil

        let stepCount = collectedTypes.contains(stepType)
            ? workoutBuilder.statistics(for: stepType)?
                .sumQuantity()?.doubleValue(for: .count())
            : nil

        Task { @MainActor [weak self] in
            guard let self, self.phase == .workout else { return }
            if cal != nil || bpm != nil || stepCount != nil {
                self.receivedFirstSample = true
            }
            if let bpm {
                self.heartRate = bpm
                self.sendLiveSnapshot()
            }
            if let stepCount { self.steps = Int(stepCount) }
            if let cal { self.checkMilestones(cal: cal) }
        }
    }
}
