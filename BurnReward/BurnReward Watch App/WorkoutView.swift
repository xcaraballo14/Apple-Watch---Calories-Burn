import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var confirmingCancel = false
    @State private var pausedBlink = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var elapsedText: String {
        WatchFormat.duration(wm.elapsedSeconds)
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
                                // The label stays small; the tappable area doesn't.
                                .frame(minWidth: 52, minHeight: 32, alignment: .leading)
                                .contentShape(Rectangle())
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

                    if let error = wm.sessionError {
                        diagnosticBanner(text: error.uppercased(), color: Theme.red)
                    } else if wm.showNoDataHint {
                        diagnosticBanner(
                            text: "NO SENSOR DATA · ON IPHONE: SETTINGS › PRIVACY & SECURITY › HEALTH › BURNREWARD",
                            color: Theme.orange
                        )
                    }

                    Button {
                        wm.togglePause()
                    } label: {
                        Label("PAUSE", systemImage: "pause.fill")
                    }
                    .buttonStyle(PixelButtonStyle(
                        fill: Theme.orange,
                        shadow: Color(red: 0.70, green: 0.25, blue: 0.08)
                    ))
                    .accessibilityLabel("Pause quest")
                    .padding(.top, 2)
                }
                .padding(.horizontal, 6)
            }

            // Milestone flash overlay
            if let earned = wm.milestoneFlash {
                milestoneOverlay(reward: earned)
            }

            // Pause takeover — sits above everything while the quest is paused.
            if wm.isPaused {
                pausedMenu
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: wm.isPaused)
        .confirmationDialog("End this quest?", isPresented: $confirmingCancel) {
            Button("End Quest", role: .destructive) { wm.newGoal() }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("It saves to history as unfinished.")
        }
    }

    // MARK: - Pause menu

    /// Classic game pause: full-screen takeover with a blinking marquee, the
    /// frozen clock, and the two choices that matter. Blink respects Reduce
    /// Motion (steady when on).
    private var pausedMenu: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 2)

            HStack(spacing: 7) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("PAUSED")
                    .font(.pixel(14))
            }
            .foregroundStyle(Theme.yellow)
            .opacity(pausedBlink ? 0.35 : 1)
            .padding(.bottom, 9)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quest paused")
            .accessibilityAddTraits(.isHeader)

            Text(elapsedText)
                .font(.pixel(11))
                .foregroundStyle(Theme.blue)
                .monospacedDigit()
                .padding(.bottom, 4)
            Text("\(Int(wm.caloriesBurned)) / \(wm.totalGoal) CAL")
                .font(.pixel(7))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button("RESUME") { wm.togglePause() }
                .buttonStyle(PixelButtonStyle())
                .accessibilityLabel("Resume quest")

            Button {
                confirmingCancel = true
            } label: {
                Text("END QUEST")
                    .font(.pixel(8))
                    .foregroundStyle(Theme.red)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(Color(white: 0.08))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .onAppear {
            pausedBlink = false
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pausedBlink = true
            }
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
            Text(stepsText)
                .font(.pixel(11))
                .foregroundStyle(Theme.blue)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("STEPS")
                .font(.pixel(5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color(white: 0.08))
        .cornerRadius(4)
    }

    /// Abbreviates past 9999 (e.g. `12.3K`) so a long workout never breaks the cell.
    private var stepsText: String {
        wm.steps > 9999
            ? String(format: "%.1fK", Double(wm.steps) / 1000)
            : "\(wm.steps)"
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

    /// Red = the session itself reported a failure; orange = the session looks
    /// alive but HealthKit has delivered nothing (usually read access is off).
    private func diagnosticBanner(text: String, color: Color) -> some View {
        Text(text)
            .font(.pixel(6))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
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
