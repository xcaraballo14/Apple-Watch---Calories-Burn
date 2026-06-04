import SwiftUI

struct EarnedView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var animating = false

    var body: some View {
        VStack(spacing: 10) {
            Text("★ EARNED! ★")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(.green)

            Text(wm.selectedReward?.emoji ?? "🏆")
                .font(.system(size: 52))
                .scaleEffect(animating ? 1.15 : 1.0)
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: animating
                )

            Text((wm.selectedReward?.name ?? "").uppercased())
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.yellow)
                .multilineTextAlignment(.center)

            Button("▶ NEW GOAL") {
                wm.newGoal()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .font(.system(.caption2, design: .monospaced).weight(.bold))
        }
        .padding()
        .onAppear { animating = true }
    }
}
