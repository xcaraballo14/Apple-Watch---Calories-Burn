import SwiftUI

struct EarnedView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var animating = false

    private var timeText: String {
        String(format: "%d:%02d", wm.summaryDuration / 60, wm.summaryDuration % 60)
    }

    var body: some View {
        ScrollView {
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

                summaryRow

                Button("▶ NEW GOAL") {
                    wm.newGoal()
                }
                .buttonStyle(PixelButtonStyle())
                .padding(.horizontal, 8)
            }
            .padding()
        }
        .onAppear { animating = true }
    }

    // MARK: - Summary

    private var summaryRow: some View {
        HStack(spacing: 6) {
            summaryCell(value: timeText,
                        label: "TIME",
                        tint: Theme.blue)
            summaryCell(value: wm.summaryAvgHR > 0 ? "\(wm.summaryAvgHR)" : "—",
                        label: "AVG ♥",
                        tint: Theme.red)
            summaryCell(value: "\(wm.summaryCalories)",
                        label: "CAL",
                        tint: Theme.orange)
        }
    }

    private func summaryCell(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.pixel(9))
                .foregroundStyle(tint)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.pixel(5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color(white: 0.08))
        .cornerRadius(4)
    }
}
