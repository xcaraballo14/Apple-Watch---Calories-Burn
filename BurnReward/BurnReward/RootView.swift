import Foundation
import SwiftUI
import UIKit

enum AppTab: Hashable {
    case home, history, rewards, guild, character
}

struct RootView: View {
    @StateObject private var model = DashboardViewModel()
    @StateObject private var liveManager = LiveQuestManager()
    @StateObject private var rewardStore = RewardStore()
    @StateObject private var guild = GuildManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The launch sign-in prompt is offered at most once per install.
    @AppStorage("br.guildPromptShown") private var guildPromptShown = false
    /// `-BRStartOn{History,Rewards,Profile,Settings}` pick the initial tab
    /// (simulator screenshots). Profile and Settings both live on CHARACTER now.
    @State private var selectedTab: AppTab = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-BRStartOnHistory") { return .history }
        if arguments.contains("-BRStartOnRewards") { return .rewards }
        if arguments.contains("-BRStartOnProfile") { return .character }
        if arguments.contains("-BRStartOnSettings") { return .character }
        if arguments.contains("-BRStartOnGuild") || arguments.contains("-BRDemoGuild")
            || arguments.contains("-BRDemoGuildClaim")
            || arguments.contains("-BRDemoAddFriend")
            || arguments.contains("-BRDemoFeed") || arguments.contains("-BRDemoParty")
            || arguments.contains("-BRDemoFeedEmpty")
            || arguments.contains("-BRDemoPostSheet")
            || arguments.contains("-BRDemoFeedTail")
            || arguments.contains("-BRDemoPostPhotos")
            || arguments.contains("-BRDemoReportSheet")
            || arguments.contains("-BRDemoBlockConfirm")
            || arguments.contains("-BRDemoMemberSheet")
            || arguments.contains("-BRDemoLeaderboard")
            || arguments.contains("-BRDemoLeaderboardJoin") { return .guild }
        return .home
    }()
    /// One-time launch sign-in prompt (Xavier's ruling). Mockup phase: the
    /// sheet only appears under `-BRDemoSignInPrompt`; the real once-per-
    /// install logic arrives with the auth wiring so an unwired prompt can
    /// never ship.
    @State private var showSignInPrompt = false

    var body: some View {
        // MOCKUP PHASE — `-BRDemoAperture` replaces the whole app with the
        // aperture-fix comparison screen so it can be screenshot in both themes.
        // Goes away with ApertureMockup.swift once Xavier locks the answers.
        if ProcessInfo.processInfo.arguments.contains("-BRDemoAperture") {
            ApertureMockupView(page: 1)
        } else if ProcessInfo.processInfo.arguments.contains("-BRDemoAperture2") {
            ApertureMockupView(page: 2)
        } else {
            appBody
        }
    }

    private var appBody: some View {
        TabView(selection: $selectedTab) {
            tabPage(HomeView(model: model, liveManager: liveManager, selectedTab: $selectedTab))
                .tag(AppTab.home)

            tabPage(HistoryView(model: model))
                .tag(AppTab.history)

            tabPage(RewardsView(store: rewardStore))
                .tag(AppTab.rewards)

            tabPage(GuildView(guild: guild,
                              level: model.stats.levelProgress.level,
                              rankTitle: LevelEngine.title(for: model.stats.levelProgress.level),
                              badgeIDs: earnedBadgeIDs,
                              weeklyXP: model.weeklyXP))
                .tag(AppTab.guild)

            tabPage(ProfileView(model: model, guild: guild, presentedAsTab: true))
                .tag(AppTab.character)
        }
        .sheet(isPresented: $showSignInPrompt) {
            GuildSignInPrompt(guild: guild) { selectedTab = .guild }
        }
        .tint(BRTheme.greenFG)
        // The console bar draws as a plain overlay; the space it occupies is
        // reserved at the WINDOW level (additionalSafeAreaInsets, below) so
        // every page and pushed screen automatically ends above it. The
        // offset cancels that same reservation for the bar itself, putting it
        // back at the physical bottom.
        .overlay(alignment: .bottom) {
            RetroTabBar(selected: $selectedTab)
                .offset(y: RetroTabBar.height)
        }
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
        .onAppear {
            reserveTabBarSpace()
            if ProcessInfo.processInfo.arguments.contains("-BRDemoSignInPrompt") {
                showSignInPrompt = true
            }
        }
        .onChange(of: model.quests) { _, _ in
            // Level/title/badges are derived from the quest list — push the new
            // summary up whenever it changes so friends see it current.
            Task {
                await guild.syncProfile(
                    level: model.stats.levelProgress.level,
                    title: LevelEngine.title(for: model.stats.levelProgress.level),
                    badgeIDs: earnedBadgeIDs
                )
            }
            // Re-publish the shared character snapshot (P3.5) — pushed only if
            // sharing is on; the manager diffs so unchanged data is a no-op.
            CharacterShare.shared.update(
                SharedCharacter.make(quests: model.quests, stats: model.stats)
            )
        }
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
            // Guild news drives the header bell, which lives on Home — so it
            // loads at the root rather than waiting for the GUILD tab to open.
            await SocialAlertStore.shared.refresh()
        }
    }

    /// Hides the system tab bar on a page (the console bar replaces it).
    private func tabPage(_ content: some View) -> some View {
        content.toolbar(.hidden, for: .tabBar)
    }

    /// Earned badge ids — the only trophy data that ever leaves the device,
    /// and only once the player has opted into the guild.
    private var earnedBadgeIDs: [String] {
        BadgeCatalog.all(for: model.quests, stats: model.stats)
            .filter(\.earned)
            .map(\.id)
    }

    /// The console bar isn't a real tab bar, so UIKit reserves no space for
    /// it. SwiftUI's `safeAreaInset` can't fix that — it doesn't propagate
    /// through UIKit-backed containers (TabView pages, NavigationStack), so
    /// bottom content hid behind the bar and could never scroll above it.
    /// Reserving the bar's height in the window root's
    /// `additionalSafeAreaInsets` does what a real tab bar does: every
    /// safe-area-aware layout — every tab, every pushed detail, every future
    /// screen — ends above the bar automatically. Sheets present in their own
    /// containers and correctly ignore it (no bar there).
    private func reserveTabBarSpace() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first,
              let root = window.rootViewController else { return }
        root.additionalSafeAreaInsets.bottom = RetroTabBar.height
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
