import Combine
import Foundation
import HealthKit

/// Receives the workout session the watch mirrors over and republishes its
/// live snapshots for the Home screen. Must be created at app launch — when
/// the watch starts mirroring, the system launches this app in the background
/// and delivers the session through `workoutSessionMirroringStartHandler`.
@MainActor
final class LiveQuestManager: NSObject, ObservableObject {
    @Published private(set) var live: LiveQuestSnapshot?

    /// Fired once after a mirrored session ends, so the dashboard can re-query
    /// HealthKit for the freshly saved workout.
    var onQuestEnded: (() -> Void)?

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?

    override init() {
        super.init()
        store.workoutSessionMirroringStartHandler = { [weak self] session in
            Task { @MainActor [weak self] in
                self?.attach(session)
            }
        }
        // QA screenshot mode: mirroring can't fire in the simulator (no paired
        // watch session), so these flags seed the live card directly. Inert in
        // any real install — matches the other -BR* launch flags.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-BRDemoLiveQuestPaused") {
            live = Self.demoSnapshot(paused: true)
        } else if args.contains("-BRDemoLiveQuest") {
            live = Self.demoSnapshot(paused: false)
        }
    }

    private static func demoSnapshot(paused: Bool) -> LiveQuestSnapshot {
        LiveQuestSnapshot(
            rewardNames: ["Cheeseburger"],
            rewardEmojis: ["🍔"],
            goalCalories: 550,
            caloriesBurned: 264,
            heartRate: 132,
            earnedCount: 0,
            startDate: Date().addingTimeInterval(-(22 * 60 + 41)),
            isPaused: paused,
            pausedSeconds: 0,
            pausedAt: paused ? Date() : nil
        )
    }

    private func attach(_ session: HKWorkoutSession) {
        self.session = session
        session.delegate = self
    }

    private func sessionEnded() {
        session = nil
        guard live != nil else { return }
        live = nil
        onQuestEnded?()
    }

    private func handle(_ payloads: [Data]) {
        guard
            let data = payloads.last,
            let snapshot = try? JSONDecoder().decode(LiveQuestSnapshot.self, from: data)
        else { return }
        live = snapshot
    }
}

extension LiveQuestManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        if toState == .ended || toState == .stopped {
            Task { @MainActor [weak self] in self?.sessionEnded() }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.sessionEnded() }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didReceiveDataFromRemoteWorkoutSession data: [Data]
    ) {
        Task { @MainActor [weak self] in self?.handle(data) }
    }
}
