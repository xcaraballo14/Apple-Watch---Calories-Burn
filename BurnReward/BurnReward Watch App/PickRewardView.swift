import SwiftUI

struct PickRewardView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var selectedIDs: Set<UUID> = []

    private let maxSelection = 2

    private var selectedRewards: [Reward] {
        allRewards.filter { selectedIDs.contains($0.id) }
    }

    private var combinedCalories: Int {
        selectedRewards.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        NavigationStack {
            List {
                // Live combo summary row
                if !selectedIDs.isEmpty {
                    HStack {
                        Text(selectedRewards
                            .sorted { $0.calories < $1.calories }
                            .map { $0.emoji }
                            .joined(separator: " + "))
                            .font(.system(.caption2, design: .monospaced))
                        Spacer()
                        Text("\(combinedCalories) CAL")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(.yellow)
                    }
                    .listRowBackground(Color(white: 0.06))
                }

                ForEach(allRewards) { reward in
                    let isSelected = selectedIDs.contains(reward.id)
                    let isFull = selectedIDs.count >= maxSelection && !isSelected

                    Button {
                        if isSelected {
                            selectedIDs.remove(reward.id)
                        } else if !isFull {
                            selectedIDs.insert(reward.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(reward.emoji)
                                .font(.title2)
                                .opacity(isFull ? 0.35 : 1.0)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(reward.name)
                                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(isFull ? .secondary : .green)
                                Text("\(reward.calories) CAL")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(isFull ? .secondary : .yellow)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                    .listRowBackground(
                        isSelected
                            ? Color.green.opacity(0.2)
                            : Color(white: 0.08)
                    )
                    .disabled(isFull)
                }

                Button("SET GOAL ▶") {
                    wm.startWorkout(for: selectedRewards)
                }
                .buttonStyle(PixelButtonStyle(enabled: !selectedIDs.isEmpty))
                .disabled(selectedIDs.isEmpty)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            }
            .listStyle(.plain)
            .navigationTitle("★ PICK REWARD")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await wm.requestAuthorization() }
    }
}
