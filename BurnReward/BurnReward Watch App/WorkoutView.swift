import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var confirmingCancel = false

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    confirmingCancel = true
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            Text(wm.selectedReward?.emoji ?? "")
                .font(.system(size: 36))

            Text((wm.selectedReward?.name ?? "").uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.green)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            expBar

            Text("\(Int(wm.caloriesBurned)) / \(wm.selectedReward?.calories ?? 0) CAL")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)

            statsRow

            #if DEBUG
            Button("+50 CAL") { wm.simulateBurn(50) }
                .buttonStyle(.bordered)
                .tint(.orange)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
            #endif
        }
        .padding(.horizontal, 6)
        .confirmationDialog("Change reward?", isPresented: $confirmingCancel) {
            Button("Go Back", role: .destructive) { wm.newGoal() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    private var expBar: some View {
        VStack(spacing: 3) {
            HStack {
                Text("EXP")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.yellow)
                Spacer()
                Text("\(Int(wm.progress * 100))%")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(.green)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(Color.yellow, lineWidth: 1.5)
                        )
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.yellow)
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

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(.orange)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color(white: 0.08))
        .cornerRadius(4)
    }
}
