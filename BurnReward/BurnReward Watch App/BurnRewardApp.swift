import SwiftUI

@main
struct BurnRewardApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var rewardLibrary = RewardLibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .environmentObject(rewardLibrary)
        }
    }
}
