import SwiftUI

/// Shown only when HealthKit itself is unavailable on the hardware — without it
/// the app can't function at all. A *denied* permission never routes here: the
/// watch's status read can be stale-wrong, so denial is a picker banner instead.
struct HealthAccessView: View {
    @EnvironmentObject var wm: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("♥")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.red)

                Text("HEALTH ACCESS\nNEEDED")
                    .font(.pixel(9))
                    .foregroundStyle(Theme.yellow)
                    .multilineTextAlignment(.center)

                Text("BurnReward needs HealthKit, which isn't available on this device.")
                    .font(.pixel(6))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                Button("↻ TRY AGAIN") {
                    Task { await wm.requestAuthorization() }
                }
                .buttonStyle(PixelButtonStyle())
                .padding(.horizontal, 6)
            }
            .padding()
        }
    }
}
