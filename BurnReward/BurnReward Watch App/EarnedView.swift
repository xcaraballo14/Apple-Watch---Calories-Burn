import SwiftUI

struct EarnedView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var animating = false

    var body: some View {
        VStack(spacing: 10) {
            Text("★ EARNED! ★")
                .font(.pixel(9))
                .foregroundStyle(Theme.green)

            HStack(spacing: 8) {
                ForEach(Array(wm.selectedRewards.enumerated()), id: \.offset) { index, reward in
                    if index > 0 {
                        Text("+")
                            .font(.pixel(10))
                            .foregroundStyle(.secondary)
                    }
                    Text(reward.emoji)
                        .font(.system(size: wm.selectedRewards.count > 1 ? 36 : 52))
                }
            }
            .scaleEffect(animating ? 1.1 : 1.0)
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: animating
            )

            Text(wm.selectedRewards
                .map { $0.name.uppercased() }
                .joined(separator: " + "))
                .font(.pixel(7))
                .foregroundStyle(Theme.yellow)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)

            Button("▶ NEW GOAL") {
                wm.newGoal()
            }
            .buttonStyle(PixelButtonStyle())
            .padding(.horizontal, 8)
        }
        .padding()
        .onAppear { animating = true }
    }
}
