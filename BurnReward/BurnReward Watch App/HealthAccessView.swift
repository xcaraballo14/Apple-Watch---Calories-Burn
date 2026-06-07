import SwiftUI

/// Shown when HealthKit is unavailable or the user denied access. Without active
/// energy we can't track the quest, so we explain what's needed instead of failing
/// silently. Styled to match the rest of the retro UI.
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

                Text(message)
                    .font(.pixel(6))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                if wm.healthAccess == .denied {
                    Text("ENABLE IN:\nWATCH › PRIVACY › HEALTH")
                        .font(.pixel(5))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                Button("↻ TRY AGAIN") {
                    Task { await wm.requestAuthorization() }
                }
                .buttonStyle(PixelButtonStyle())
                .padding(.horizontal, 6)
            }
            .padding()
        }
    }

    private var message: String {
        switch wm.healthAccess {
        case .unavailable:
            return "BurnReward needs HealthKit, which isn't available on this device."
        default:
            return "BurnReward needs active calories to track your quest."
        }
    }
}
