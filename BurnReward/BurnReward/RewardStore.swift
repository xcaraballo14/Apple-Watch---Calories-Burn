import Combine
import Foundation
import SwiftUI

/// Owns the reward library on the iPhone — the "phone is the brain" store.
/// Every mutation persists locally and pushes the whole library to the watch.
@MainActor
final class RewardStore: ObservableObject {
    @Published private(set) var library: RewardLibrary

    private let sync = WatchSyncService()
    private static let defaultsKey = "br.rewardLibrary"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = RewardLibrary.decoded(from: data) {
            library = saved
        } else {
            library = RewardLibrary()
        }
        // Re-push on every launch so a reinstalled or reset watch catches up.
        sync.push(library)
    }

    var customRewards: [Reward] { library.customRewards }

    func isHidden(_ reward: Reward) -> Bool {
        library.hiddenBuiltInNames.contains(reward.name)
    }

    /// Names are the identity the watch persists selections by, so they must
    /// stay unique across built-ins and customs (case-insensitive).
    func nameIsTaken(_ name: String) -> Bool {
        let candidate = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty else { return false }
        return (allRewards + library.customRewards)
            .contains { $0.name.lowercased() == candidate }
    }

    func addCustom(name: String, emoji: String, calories: Int, flavorText: String) {
        // "|" is the quest-metadata separator (QuestMetadata.separator); it can
        // never enter a name or emoji or the saved workout history would parse
        // wrong forever. The builder blocks it in the UI; this is the backstop.
        let cleanName = name
            .replacingOccurrences(of: "|", with: "")
            .trimmingCharacters(in: .whitespaces)
        let cleanEmoji = emoji.replacingOccurrences(of: "|", with: "")
        let reward = Reward(
            emoji: cleanEmoji.isEmpty ? "⭐" : cleanEmoji,
            name: cleanName,
            calories: calories,
            description: flavorText.isEmpty ? "Custom reward" : flavorText
        )
        guard !reward.name.isEmpty else { return }
        library.customRewards.append(reward)
        commit()
    }

    func deleteCustoms(at offsets: IndexSet) {
        library.customRewards.remove(atOffsets: offsets)
        commit()
    }

    func moveCustoms(from source: IndexSet, to destination: Int) {
        library.customRewards.move(fromOffsets: source, toOffset: destination)
        commit()
    }

    func toggleHidden(_ reward: Reward) {
        if !library.hiddenBuiltInNames.insert(reward.name).inserted {
            library.hiddenBuiltInNames.remove(reward.name)
        }
        commit()
    }

    private func commit() {
        UserDefaults.standard.set(library.encoded(), forKey: Self.defaultsKey)
        sync.push(library)
    }
}
