import SwiftUI

struct EarnedView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var animating = false

    var body: some View {
        VStack(spacing: 10) {
            Text("★ EARNED! ★")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(.green)

            HStack(spacing: 8) {
                ForEach(Array(wm.selectedRewards.enumerated()), id: \.offset) { index, reward in
                    if index > 0 {
                        Text("+")
                            .font(.system(.caption, design: .monospaced))
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
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.yellow)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.65)

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
