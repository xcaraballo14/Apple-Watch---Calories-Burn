import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var confirmingCancel = false

    private var elapsedText: String {
        String(format: "%d:%02d", wm.elapsedSeconds / 60, wm.elapsedSeconds % 60)
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 6) {
                    HStack {
                        Button {
                            confirmingCancel = true
                        } label: {
                            Label("BACK", systemImage: "chevron.left")
                                .font(.pixel(6))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(elapsedText)
                            .font(.pixel(8))
                            .foregroundStyle(Theme.blue)
                            .monospacedDigit()
                    }

                    rewardEmojis

                    expBar

                    Text("\(Int(wm.caloriesBurned)) / \(wm.totalGoal) CAL")
                        .font(.pixel(8))
                        .foregroundStyle(Theme.green)
                        .monospacedDigit()

                    statsRow
                    HStack(spacing: 6) {
                        heartRateCell
                        stepsCell
                    }

                    #if DEBUG
                    Button("+50 CAL") { wm.simulateBurn(50) }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .font(.pixel(7))
                    #endif
                }
                .padding(.horizontal, 6)
            }

            // Milestone flash overlay
            if let earned = wm.milestoneFlash {
                milestoneOverlay(reward: earned)
            }
        }
        .confirmationDialog("Change reward?", isPresented: $confirmingCancel) {
            Button("Go Back", role: .destructive) { wm.newGoal() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: - Subviews

    private var rewardEmojis: some View {
        HStack(spacing: 6) {
            ForEach(Array(wm.selectedRewards.enumerated()), id: \.offset) { index, reward in
                if index > 0 {
                    Text("+")
                        .font(.pixel(8))
                        .foregroundStyle(.secondary)
                }
                ZStack(alignment: .bottomTrailing) {
                    Text(reward.emoji)
                        .font(.system(size: wm.selectedRewards.count > 1 ? 28 : 36))
                        .opacity(index < wm.earnedCount ? 0.4 : 1.0)
                    if index < wm.earnedCount {
                        Text("✓")
                            .font(.system(size: 10, design: .monospaced).weight(.bold))
                            .foregroundStyle(Theme.green)
                    }
                }
            }
        }
    }

    private var expBar: some View {
        VStack(spacing: 3) {
            HStack {
                Text("EXP")
                    .font(.pixel(7))
                    .foregroundStyle(Theme.yellow)
                Spacer()
                Text("\(Int(wm.progress * 100))%")
                    .font(.pixel(11))
                    .foregroundStyle(Theme.green)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(Theme.yellow, lineWidth: 1.5)
                        )
                    // Milestone marker line for combo goals
                    if wm.selectedRewards.count > 1, wm.totalGoal > 0 {
                        let first = wm.selectedRewards[0]
                        let markerX = geo.size.width * Double(first.calories) / Double(wm.totalGoal)
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 2, height: 12)
                            .offset(x: markerX - 1)
                    }
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.yellow)
                        .frame(width: geo.size.width * wm.progress)
                        .animation(.easeInOut(duration: 0.3), value: wm.progress)
                }
            }
            .frame(height: 12)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 6) {
            statCell(value: "\(Int(wm.caloriesBurned))", label: "BURNED")
            statCell(value: "\(wm.caloriesLeft)", label: "LEFT")
        }
    }

    private var heartRateCell: some View {
        HStack(spacing: 4) {
            Text("♥")
                .font(.system(size: 12))
                .foregroundStyle(Theme.red)
            Text(wm.heartRate > 0 ? "\(Int(wm.heartRate))" : "—")
                .font(.pixel(11))
                .foregroundStyle(Theme.red)
                .monospacedDigit()
            Text("BPM")
                .font(.pixel(5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color(white: 0.08))
        .cornerRadius(4)
    }

    private var stepsCell: some View {
        HStack(spacing: 4) {
            Text("👟")
                .font(.system(size: 11))
            Text("\(wm.steps)")
                .font(.pixel(11))
                .foregroundStyle(Theme.blue)
                .monospacedDigit()
            Text("STEPS")
                .font(.pixel(5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color(white: 0.08))
        .cornerRadius(4)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.pixel(13))
                .foregroundStyle(Theme.orange)
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

    private func milestoneOverlay(reward: Reward) -> some View {
        VStack(spacing: 4) {
            Text(reward.emoji).font(.system(size: 32))
            Text("EARNED!").font(.pixel(9))
                .foregroundStyle(Theme.green)
            Text("KEEP GOING →").font(.pixel(6))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.black.opacity(0.85))
        .cornerRadius(8)
        .transition(.scale.combined(with: .opacity))
        .animation(.easeOut(duration: 0.2), value: wm.milestoneFlash != nil)
    }
}
