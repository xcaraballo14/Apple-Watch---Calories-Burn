import Foundation
import SwiftUI
import UIKit

enum AppTab: Hashable {
    case home, history, rewards, character
}

struct RootView: View {
    @StateObject private var model = DashboardViewModel()
    @StateObject private var liveManager = LiveQuestManager()
    @StateObject private var rewardStore = RewardStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `-BRStartOn{History,Rewards,Profile,Settings}` pick the initial tab
    /// (simulator screenshots). Profile and Settings both live on CHARACTER now.
    @State private var selectedTab: AppTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-BRStartOnHistory") { return .history }
        if arguments.contains("-BRStartOnRewards") { return .rewards }
        if arguments.contains("-BRStartOnProfile") { return .character }
        if arguments.contains("-BRStartOnSettings") { return .character }
        return .home
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(model: model, liveManager: liveManager, selectedTab: $selectedTab)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.home)

            HistoryView(model: model)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.history)

            RewardsView(store: rewardStore)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.rewards)

            ProfileView(model: model, presentedAsTab: true)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.character)
        }
        // The system tab bar is hidden on every tab; this console bar replaces
        // it — full-width, edge-to-edge, into the home-indicator area.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RetroTabBar(selected: $selectedTab)
        }
        .tint(BRTheme.greenFG)
        // Celebration toast (badge unlocks + record breaks) — sits above the
        // TabView so it shows no matter which tab the refresh lands on. One at
        // a time; the queue in the model feeds the next when this one dismisses.
        .overlay(alignment: .top) {
            if let celebration = model.celebrations.first {
                CelebrationToast(celebration: celebration) {
                    selectedTab = .character   // straight to the trophy case
                    model.dismissCelebration()
                } onTimeout: {
                    model.dismissCelebration()
                }
                .id(celebration.id)   // consecutive items re-run the transition
                .transition(reduceMotion
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45),
                   value: model.celebrations.first?.id)
        .task {
            liveManager.onQuestEnded = { [weak model] in
                // The watch is still finalizing the HKWorkout save when the
                // session ends — give it a beat before re-querying.
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    await model?.refresh()
                }
            }
            await model.refresh()
        }
    }
}

/// The "item get" banner — badge unlocks and record breaks share it.
/// Deliberately loud (gold on the dark island) but short-lived; tapping it
/// opens the character sheet, waiting dismisses it.
private struct CelebrationToast: View {
    let celebration: Celebration
    let onTap: () -> Void
    let onTimeout: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Badge celebrations carry id "badge_<id>", which is exactly
                // the art asset name — drawn medallion when it exists.
                if let art = UIImage(named: celebration.id) {
                    Image(uiImage: art)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                } else {
                    ZStack {
                        Circle()
                            .fill(BRTheme.gold.opacity(0.18))
                            .overlay(Circle().strokeBorder(BRTheme.gold, lineWidth: 1))
                            .frame(width: 44, height: 44)
                        Text(celebration.emoji).font(.system(size: 22))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(celebration.headline)
                        .font(.pixel(8))
                        .foregroundStyle(BRTheme.expFill)
                    Text(celebration.title)
                        .font(.pixel(10))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BRTheme.mutedOnDark)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BRTheme.darkIsland)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(BRTheme.gold, lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(celebration.headline) \(celebration.title). \(celebration.detail).")
        .accessibilityHint("Opens your character sheet.")
        .onAppear {
            // One crisp success tap per celebration — the iPhone cousin of the
            // watch's milestone haptics. The system setting can silence it.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UIAccessibility.post(notification: .announcement,
                                 argument: "\(celebration.headline) \(celebration.title)")
        }
        // Auto-dismiss; VoiceOver users get double the dwell time. The demo
        // flag pins the toast open so simulator screenshots can catch it.
        .task(id: celebration.id) {
            let demo = ProcessInfo.processInfo.arguments.contains("-BRDemoBadgeToast")
            let seconds: Double = demo
                ? 300
                : (UIAccessibility.isVoiceOverRunning
                    ? GameBalance.toastSecondsVoiceOver
                    : GameBalance.toastSeconds)
            try? await Task.sleep(for: .seconds(seconds))
            onTimeout()
        }
    }
}

#Preview("Root") {
    RootView()
}
