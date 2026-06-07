import SwiftUI
import WatchKit

struct PickRewardView: View {
    @EnvironmentObject var wm: WorkoutManager
    @State private var selectedIDs: Set<String> = []
    @State private var workoutType: WorkoutType = .walk
    @State private var rejectFlash = false   // pulses the header when a 3rd tap is rejected

    private let maxSelection = 2

    private var selectedRewards: [Reward] {
        allRewards.filter { selectedIDs.contains($0.id) }
    }

    private var combinedCalories: Int {
        selectedRewards.reduce(0) { $0 + $1.calories }
    }

    private var isFull: Bool { selectedIDs.count >= maxSelection }

    var body: some View {
        Group {
            switch wm.healthAccess {
            case .denied, .unavailable:
                HealthAccessView()
            default:
                picker
            }
        }
        .task { await wm.requestAuthorization() }
    }

    private var picker: some View {
        NavigationStack {
            List {
                helperHeader

                // Live combo summary row
                if !selectedIDs.isEmpty {
                    HStack {
                        Text(selectedRewards
                            .sorted { $0.calories < $1.calories }
                            .map { $0.emoji }
                            .joined(separator: " + "))
                            .font(.system(size: 16))
                        Spacer()
                        Text("\(combinedCalories) CAL")
                            .font(.pixel(8))
                            .foregroundStyle(Theme.yellow)
                    }
                    .listRowBackground(Color(white: 0.06))
                }

                ForEach(allRewards) { reward in
                    rewardRow(for: reward)
                }

                workoutTypeSection

                Button("SET GOAL ▶") {
                    wm.startWorkout(for: selectedRewards, type: workoutType)
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
    }

    // MARK: - Helper header

    private var helperHeader: some View {
        Text(isFull ? "MAX REACHED · TAP ✓ TO SWAP" : "PICK UP TO 2 REWARDS")
            .font(.pixel(6))
            .foregroundStyle(headerColor)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .scaleEffect(rejectFlash ? 1.12 : 1.0)
            .animation(.easeOut(duration: 0.18), value: rejectFlash)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 4, trailing: 4))
    }

    private var headerColor: Color {
        if rejectFlash { return Theme.red }
        return isFull ? Theme.orange : Theme.muted
    }

    // MARK: - Reward row

    @ViewBuilder
    private func rewardRow(for reward: Reward) -> some View {
        let isSelected = selectedIDs.contains(reward.id)
        let dimmed = isFull && !isSelected

        Button {
            tap(reward, isSelected: isSelected)
        } label: {
            HStack(spacing: 8) {
                Text(reward.emoji)
                    .font(.title2)
                    .opacity(dimmed ? 0.4 : 1.0)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reward.name.uppercased())
                        .font(.pixel(7))
                        .foregroundStyle(dimmed ? Color.secondary : Theme.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text("\(reward.calories) CAL")
                        .font(.pixel(6))
                        .foregroundStyle(dimmed ? Color.secondary : Theme.yellow)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected ? Color.green.opacity(0.2) : Color(white: 0.08)
        )
    }

    /// Handle a tap. A 3rd selection is rejected with a failure haptic + header
    /// flash rather than silently doing nothing.
    private func tap(_ reward: Reward, isSelected: Bool) {
        if isSelected {
            selectedIDs.remove(reward.id)
            WKInterfaceDevice.current().play(.click)
        } else if selectedIDs.count < maxSelection {
            selectedIDs.insert(reward.id)
            WKInterfaceDevice.current().play(.click)
        } else {
            WKInterfaceDevice.current().play(.failure)
            rejectFlash = true
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                rejectFlash = false
            }
        }
    }

    // MARK: - Workout type

    private var workoutTypeSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("WORKOUT TYPE")
                .font(.pixel(5))
                .foregroundStyle(Theme.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(WorkoutType.allCases) { type in
                        typeChip(type)
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }

    private func typeChip(_ type: WorkoutType) -> some View {
        let selected = workoutType == type
        return Button {
            workoutType = type
            WKInterfaceDevice.current().play(.click)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: type.icon)
                    .font(.system(size: 15))
                Text(type.label)
                    .font(.pixel(5))
            }
            .frame(width: 46, height: 42)
            .foregroundStyle(selected ? .black : Theme.green)
            .background(selected ? Theme.green : Color(white: 0.1))
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
