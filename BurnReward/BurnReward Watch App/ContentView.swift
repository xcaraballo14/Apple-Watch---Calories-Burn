import SwiftUI

struct ContentView: View {
    @EnvironmentObject var wm: WorkoutManager

    var body: some View {
        Group {
            switch wm.phase {
            case .picking:  PickRewardView()
            case .workout:  WorkoutView()
            // Scanlines stay on the celebration screen, where the retro punch is
            // wanted — they're dropped from picking/workout so live metrics read cleanly.
            case .earned:   EarnedView().overlay(ScanlineOverlay())
            }
        }
        .animation(.easeInOut(duration: 0.25), value: wm.phase)
    }
}
