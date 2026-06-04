import SwiftUI

struct PickRewardView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var selected: Reward?

    var body: some View {
        NavigationStack {
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
            .navigationTitle("★ PICK REWARD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        if let r = selected { wm.startWorkout(for: r) }
                    } label: {
                        Text("SET GOAL ▶")
                            .font(.system(.footnote, design: .monospaced).weight(.bold))
                    }
                    .disabled(selected == nil)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
        .task { await wm.requestAuthorization() }
    }
}
