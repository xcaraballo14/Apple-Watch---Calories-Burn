import SwiftUI

struct PickRewardView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var selected: Reward?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List(allRewards) { reward in
                    Button { selected = reward } label: {
                        HStack(spacing: 8) {
                            Text(reward.emoji)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reward.name)
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(.green)
                                Text("\(reward.calories) CAL")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.yellow)
                            }
                            Spacer()
                            if selected?.id == reward.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    .listRowBackground(
                        selected?.id == reward.id
                            ? Color.green.opacity(0.2)
                            : Color(white: 0.08)
                    )
                }
                .listStyle(.plain)

                Button("SET GOAL ▶") {
                    if let r = selected { wm.startWorkout(for: r) }
                }
                .buttonStyle(PixelButtonStyle(enabled: selected != nil))
                .disabled(selected == nil)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .navigationTitle("★ PICK REWARD")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await wm.requestAuthorization() }
    }
}
