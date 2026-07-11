import SwiftUI

struct RewardsView: View {
    @ObservedObject var store: RewardStore
    @State private var showBuilder = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRTabHeader("REWARD FORGE") {
                    EditButton()
                        .font(.subheadline)
                        .tint(BRTheme.blueFG)
                }
                rewardList
            }
            .background(BRTheme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.editMode, $editMode)
        }
        .sheet(isPresented: $showBuilder) {
            RewardBuilderView(store: store)
        }
    }

    private var rewardList: some View {
            List {
                Section {
                    if store.customRewards.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NOTHING FORGED YET")
                                .font(.pixel(10))
                                .foregroundStyle(BRTheme.textPrimary)
                            Text("Create any food with its calorie goal — it lands on your watch picker automatically.")
                                .font(.footnote)
                                .foregroundStyle(BRTheme.textMuted)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(BRTheme.card)
                    } else {
                        ForEach(store.customRewards) { reward in
                            customRow(reward)
                        }
                        .onDelete { store.deleteCustoms(at: $0) }
                        .onMove { store.moveCustoms(from: $0, to: $1) }
                    }

                    Button {
                        showBuilder = true
                    } label: {
                        Label("Forge new reward", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(BRTheme.greenFG)
                    }
                    .listRowBackground(BRTheme.card)
                } header: {
                    Text("YOUR REWARDS")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.textMuted)
                }

                Section {
                    ForEach(allRewards) { reward in
                        builtInRow(reward)
                    }
                } header: {
                    Text("BUILT-IN")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.textMuted)
                } footer: {
                    Text("Hidden rewards stay off the watch picker. Every change syncs to your watch automatically — no servers involved.")
                        .font(.footnote)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
    }

    private func customRow(_ reward: Reward) -> some View {
        HStack(spacing: 10) {
            Text(reward.emoji)
                .font(.system(size: 22))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(reward.name)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textPrimary)
                    .lineLimit(1)
                Text(reward.description)
                    .font(.caption)
                    .foregroundStyle(BRTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text("\(reward.calories) CAL")
                .font(.pixel(9))
                .foregroundStyle(BRTheme.yellowFG)
        }
        .padding(.vertical, 2)
        .listRowBackground(BRTheme.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reward.name), \(reward.calories) calories, custom reward.")
    }

    private func builtInRow(_ reward: Reward) -> some View {
        let hidden = store.isHidden(reward)
        return HStack(spacing: 10) {
            Text(reward.emoji)
                .font(.system(size: 22))
                .opacity(hidden ? 0.35 : 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(reward.name)
                    .font(.footnote)
                    .foregroundStyle(hidden ? BRTheme.textMuted : BRTheme.textPrimary)
                    .lineLimit(1)
                Text("\(reward.calories) cal")
                    .font(.caption)
                    .foregroundStyle(BRTheme.textMuted)
            }
            Spacer(minLength: 8)
            Button {
                store.toggleHidden(reward)
            } label: {
                Image(systemName: hidden ? "eye.slash" : "eye")
                    .font(.system(size: 15))
                    .foregroundStyle(hidden ? BRTheme.textMuted : BRTheme.blueFG)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(hidden ? "Show \(reward.name) on the watch picker" : "Hide \(reward.name) from the watch picker")
        }
        .listRowBackground(BRTheme.card)
    }
}

struct RewardBuilderView: View {
    @ObservedObject var store: RewardStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = ""
    @State private var caloriesText = ""
    @State private var flavorText = ""

    private static let suggestedEmojis = [
        "🍕", "🍩", "🍪", "🍔", "🌮", "🍫", "🧁", "🍦",
        "🥤", "🧋", "🍜", "🍟", "🍣", "🍺", "🥟", "🍰",
    ]

    private var calories: Int? {
        guard let value = Int(caloriesText), (10...5000).contains(value) else { return nil }
        return value
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var nameTaken: Bool { store.nameIsTaken(trimmedName) }

    /// "|" is the quest-metadata separator stamped onto saved workouts
    /// (QuestMetadata.separator) — a name containing it would corrupt the
    /// reward list the iPhone reconstructs, permanently (metadata is immutable).
    private var nameHasPipe: Bool { trimmedName.contains("|") }

    private var canSave: Bool { !trimmedName.isEmpty && !nameTaken && !nameHasPipe && calories != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reward") {
                    TextField("Name (e.g. Abuela's Flan)", text: $name)
                    if nameTaken {
                        Text("That name already exists — names must be unique.")
                            .font(.caption)
                            .foregroundStyle(BRTheme.alertRed)
                    } else if nameHasPipe {
                        Text("Names can't contain the | character.")
                            .font(.caption)
                            .foregroundStyle(BRTheme.alertRed)
                    }
                    TextField("Calories to earn it (10–5000)", text: $caloriesText)
                        .keyboardType(.numberPad)
                    TextField("Flavor text (optional)", text: $flavorText)
                }
                .listRowBackground(BRTheme.card)
                Section("Emoji") {
                    TextField("Pick below or type your own", text: $emoji)
                        .onChange(of: emoji) { _, newValue in
                            // One character, and never the metadata separator.
                            emoji = String(newValue.filter { $0 != "|" }.suffix(1))
                        }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 6) {
                        ForEach(Self.suggestedEmojis, id: \.self) { candidate in
                            Button {
                                emoji = candidate
                            } label: {
                                Text(candidate)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(emoji == candidate ? BRTheme.tintGreen : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use \(candidate) emoji")
                        }
                    }
                }
                .listRowBackground(BRTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(BRTheme.bg)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("FORGE REWARD")
                        .font(.pixel(12))
                        .foregroundStyle(BRTheme.greenFG)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let calories else { return }
                        store.addCustom(
                            name: trimmedName,
                            emoji: emoji,
                            calories: calories,
                            flavorText: flavorText.trimmingCharacters(in: .whitespaces)
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("Rewards") {
    RewardsView(store: RewardStore())
}
