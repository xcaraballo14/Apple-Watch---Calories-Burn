import SwiftUI

struct ContentView: View {
    @EnvironmentObject var wm: WorkoutManager

    var body: some View {
        Group {
            switch wm.phase {
            case .picking:  PickRewardView()
            case .workout:  WorkoutView()
            case .earned:   EarnedView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: wm.phase)
        .overlay(ScanlineOverlay())
    }
}
