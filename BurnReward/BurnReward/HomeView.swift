import Foundation
import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject var model: DashboardViewModel
    @ObservedObject var liveManager: LiveQuestManager
    @Binding var selectedTab: AppTab

    @AppStorage("br.displayName") private var displayName = ""
    @AppStorage("br.avatarJPEG") private var avatarData = Data()
    /// `-BRStartOnAlerts` auto-presents the alerts sheet at launch (screenshots / QA).
    @State private var showAlerts = ProcessInfo.processInfo.arguments.contains("-BRStartOnAlerts")
    @Environment(\.scenePhase) private var scenePhase

    /// Drives the bell's red dot — true when an achievement event is newer than
    /// the last time the alerts sheet was opened.
    private var hasUnreadAlerts: Bool { model.hasUnreadAlerts }
    /// Observed so the bell dot appears the moment guild news lands, not on
    /// the next unrelated redraw.
    @ObservedObject private var social = SocialAlertStore.shared

    var body: some View {
        let stats = model.stats
        NavigationStack {
            ZStack {
                BRTheme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.footnote)
                            .foregroundStyle(BRTheme.textMuted)
                            .padding(.bottom, 2)

                        // The EXP card opens the character sheet (Xavier's ask).
                        Button {
                            selectedTab = .character
                        } label: {
                            LevelCard(progress: stats.levelProgress)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens your character sheet.")

                        if let live = liveManager.live {
                            LiveQuestCard(snapshot: live)
                        } else if let quest = model.lastQuest {
                            // The hero card drills into the full quest receipt.
                            NavigationLink(value: quest) {
                                LastQuestCard(quest: quest)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Shows the quest details and XP receipt.")
                        } else {
                            EmptyQuestCard(state: model.state)
                        }

                        if let challenge = model.weeklyChallenge {
                            WeeklyChallengeCard(challenge: challenge)
                        }

                        Button {
                            selectedTab = .history
                        } label: {
                            WeekStripCard(stats: stats)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens History and the weekly burn chart.")

                        StatTilesRow(stats: stats)

                        if !model.recentQuests.isEmpty {
                            QuestLogCard(quests: model.recentQuests, scores: model.scores) {
                                selectedTab = .history
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable { await model.refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)   // Home keeps its custom header
            .navigationDestination(for: Quest.self) { quest in
                QuestDetailView(quest: quest, xp: model.xpBreakdown(for: quest),
                                recordKinds: model.recordKinds(for: quest),
                                shareContext: ShareContext(
                                    level: model.stats.levelProgress.level,
                                    rankTitle: LevelEngine.title(for: model.stats.levelProgress.level),
                                    playerName: displayName
                                ))
            }
        }
        .sheet(isPresented: $showAlerts) {
            NotificationsView(model: model) { selectedTab = .guild }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                selectedTab = .character
            } label: {
                AvatarBadge(
                    name: displayName,
                    size: 44,
                    photoData: avatarData.isEmpty ? nil : avatarData
                )
            }
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .accessibilityLabel("Character sheet")

            Spacer()

            Text("BURNREWARD")
                .font(.pixel(12))
                .foregroundStyle(BRTheme.greenFG)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                showAlerts = true
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 20))
                    .foregroundStyle(BRTheme.textMuted)
                    .overlay(alignment: .topTrailing) {
                        if hasUnreadAlerts {
                            Circle()
                                .fill(BRTheme.alertRed)
                                .frame(width: 9, height: 9)
                                .offset(x: 2, y: -2)
                        }
                    }
            }
            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            .accessibilityLabel(hasUnreadAlerts ? "Notifications, unread alerts" : "Notifications")
        }
    }
}

// MARK: - Avatar

struct AvatarBadge: View {
    let name: String
    var size: CGFloat = 36
    var photoData: Data? = nil

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return parts.map(String.init).joined().uppercased()
    }

    var body: some View {
        Circle()
            .fill(BRTheme.darkIsland)
            .frame(width: size, height: size)
            .overlay {
                if let photoData, let photo = UIImage(data: photoData) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        // Clipping is drawing-only; without this a portrait
                        // photo's invisible overflow eats taps around the
                        // avatar (and silently widens its own tap target).
                        .contentShape(Circle())
                } else if initials.isEmpty {
                    Image(systemName: "flame.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(BRTheme.neonGreen)
                } else {
                    Text(initials)
                        .font(.pixel(size * 0.3))
                        .foregroundStyle(BRTheme.neonGreen)
                }
            }
            .overlay(Circle().strokeBorder(BRTheme.weekBorder, lineWidth: 1))
    }
}

// MARK: - Progress bar

struct BRProgressBar: View {
    let fraction: Double
    let fill: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(BRTheme.track)
                if fraction > 0 {
                    Capsule()
                        .fill(fill)
                        .frame(width: max(height, geo.size.width * min(fraction, 1)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Level card

struct LevelCard: View {
    let progress: LevelEngine.Progress

    /// The next rank name — nil while the next level keeps the same title
    /// (mid-band, or FEAST OVERLORD at the top), so the card never points at
    /// the rank you already hold.
    private var nextTitle: String? {
        let next = LevelEngine.title(for: progress.level + 1)
        return next == progress.title ? nil : next
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 3) {
                Text("LVL")
                    .font(.pixel(10))
                    .foregroundStyle(BRTheme.mutedOnDark)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(progress.level)")
                    .font(.pixel(16))
                    .foregroundStyle(BRTheme.expFill)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(width: 54, height: 54)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(BRTheme.darkIsland))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(BRTheme.gold, lineWidth: 1))

            VStack(alignment: .leading, spacing: 7) {
                Text(progress.title)
                    .font(.pixel(11))
                    .foregroundStyle(BRTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                BRProgressBar(fraction: progress.fraction, fill: BRTheme.xpFill)
                // The visible gap: where you are, and — when the next level
                // changes your rank — the title you're climbing toward.
                HStack(spacing: 4) {
                    Text("\(progress.xpIntoLevel.formatted()) / \(progress.xpLevelSpan.formatted()) XP to LVL \(progress.level + 1)")
                        .font(.caption2)
                        .foregroundStyle(BRTheme.textMuted)
                    if let nextTitle {
                        Text("→ \(nextTitle)")
                            .font(.pixel(7))
                            .foregroundStyle(BRTheme.greenFG)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Level \(progress.level), \(progress.title.lowercased()). " +
            "\(progress.xpIntoLevel) of \(progress.xpLevelSpan) experience points to level \(progress.level + 1)" +
            (nextTitle.map { ", next rank \($0.lowercased())" } ?? "") + "."
        )
    }
}

// MARK: - Last quest hero card

struct LastQuestCard: View {
    let quest: Quest

    private var percentText: String {
        guard let fraction = quest.progressToGoal else { return "" }
        return "\((fraction * 100).formatted(.number.precision(.fractionLength(0))))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PixelSectionLabel(text: "LAST QUEST")
                Spacer()
                Text("\(BRFormat.recentDay(quest.endDate)) · \(quest.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(BRTheme.textMuted)
            }

            HStack(spacing: 12) {
                Text(quest.emoji)
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(quest.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(BRTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(BRTheme.textMuted)
                }
                Spacer(minLength: 8)
                badge
            }

            if let fraction = quest.progressToGoal, let goal = quest.goalCalories {
                BRProgressBar(fraction: fraction, fill: BRTheme.expFill, height: 10)
                HStack {
                    Text("\(quest.calories) / \(goal) CAL")
                    Spacer()
                    Text(percentText)
                }
                .font(.pixel(11))
                .foregroundStyle(BRTheme.yellowFG)
            }

            HStack(spacing: 0) {
                statCell(value: BRFormat.duration(quest.duration), label: "TIME")
                divider
                statCell(value: quest.averageHeartRate.map { "\($0)" } ?? "—", label: "AVG HR")
                divider
                statCell(value: "\(quest.calories)", label: "CALORIES")
            }
            .padding(.top, 2)
            .overlay(alignment: .top) {
                Rectangle().fill(BRTheme.divider).frame(height: 1).offset(y: -6)
            }
        }
        .brCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var subtitle: String {
        if quest.isLegacy {
            return "\(quest.activityLabel.capitalized) · saved from Apple Watch"
        }
        if let goal = quest.goalCalories {
            return "\(quest.activityLabel.capitalized) · \(goal) cal goal"
        }
        return quest.activityLabel.capitalized
    }

    private var badge: some View {
        Group {
            if quest.earned {
                Text("EARNED")
                    .font(.pixel(11))
                    .foregroundStyle(BRTheme.onNeonGreen)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BRTheme.neonGreen))
            } else {
                Text("UNFINISHED")
                    .font(.pixel(11))
                    .foregroundStyle(BRTheme.textMuted)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BRTheme.weekBorder, lineWidth: 1))
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(BRTheme.divider).frame(width: 1, height: 32)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BRTheme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(BRTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var accessibilitySummary: String {
        var parts = ["Last quest: \(quest.title), \(quest.earned ? "earned" : "unfinished")."]
        if let goal = quest.goalCalories {
            parts.append("\(quest.calories) of \(goal) calories.")
        } else {
            parts.append("\(quest.calories) calories.")
        }
        parts.append("Duration \(BRFormat.duration(quest.duration)).")
        if let hr = quest.averageHeartRate {
            parts.append("Average heart rate \(hr).")
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Live quest (mirrored from the watch)

struct LiveQuestCard: View {
    let snapshot: LiveQuestSnapshot

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    private var allEarned: Bool {
        !snapshot.rewardNames.isEmpty && snapshot.earnedCount >= snapshot.rewardNames.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot.isPaused ? BRTheme.orangeFG : BRTheme.alertRed)
                        .frame(width: 8, height: 8)
                        // The heartbeat stops while paused — a still dot reads
                        // "held", not "recording".
                        .opacity(snapshot.isPaused || reduceMotion ? 1 : (pulsing ? 0.3 : 1))
                        .accessibilityHidden(true)
                    PixelSectionLabel(text: "CURRENT QUEST")
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    // Freezes at the pause point and excludes paused spans —
                    // the same seconds the watch shows.
                    Text(BRFormat.duration(snapshot.elapsedSeconds(at: context.date)))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(snapshot.isPaused ? BRTheme.textMuted : BRTheme.textPrimary)
                }
            }

            HStack(spacing: 12) {
                Text(snapshot.emoji)
                    .font(.system(size: 40))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(BRTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(snapshot.goalCalories) cal goal")
                        .font(.caption)
                        .foregroundStyle(BRTheme.textMuted)
                }
                Spacer(minLength: 8)
                if allEarned {
                    Text("EARNED")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BRTheme.neonGreen))
                } else if snapshot.isPaused {
                    Text("PAUSED")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.orangeFG)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BRTheme.orangeFG, lineWidth: 1))
                } else {
                    Text("LIVE")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.alertRed)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BRTheme.alertRed, lineWidth: 1))
                }
            }

            BRProgressBar(fraction: snapshot.progress, fill: BRTheme.expFill, height: 10)
            HStack {
                Text("\(Int(snapshot.caloriesBurned)) / \(snapshot.goalCalories) CAL")
                Spacer()
                Text("\((snapshot.progress * 100).formatted(.number.precision(.fractionLength(0))))%")
            }
            .font(.pixel(11))
            .foregroundStyle(BRTheme.yellowFG)

            HStack(spacing: 0) {
                liveStatCell(value: snapshot.heartRate > 0 ? "\(Int(snapshot.heartRate))" : "—", label: "HR")
                Rectangle().fill(BRTheme.divider).frame(width: 1, height: 32)
                liveStatCell(value: "\(Int(snapshot.caloriesBurned))", label: "BURNED")
                Rectangle().fill(BRTheme.divider).frame(width: 1, height: 32)
                liveStatCell(value: "\(snapshot.caloriesLeft)", label: "TO GO")
            }
            .padding(.top, 2)
            .overlay(alignment: .top) {
                Rectangle().fill(BRTheme.divider).frame(height: 1).offset(y: -6)
            }
        }
        .brCard()
        .onAppear { pulsing = true }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
            value: pulsing
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Current quest, \(snapshot.isPaused ? "paused" : "live"): \(snapshot.title). " +
            "\(Int(snapshot.caloriesBurned)) of \(snapshot.goalCalories) calories, \(snapshot.caloriesLeft) to go." +
            (snapshot.heartRate > 0 ? " Heart rate \(Int(snapshot.heartRate))." : "")
        )
    }

    private func liveStatCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BRTheme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(BRTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

/// First-run state before any quest exists (or while HealthKit loads).
struct EmptyQuestCard: View {
    let state: DashboardViewModel.LoadState

    var body: some View {
        let failed = state == .failed
        return VStack(spacing: 10) {
            Image(systemName: failed ? "exclamationmark.arrow.circlepath" : "flame.fill")
                .font(.system(size: 28))
                .foregroundStyle(failed ? BRTheme.textMuted : BRTheme.neonGreen)
                .accessibilityHidden(true)
            Text(state == .loading ? "LOADING QUESTS…" : failed ? "COULDN'T LOAD" : "NO QUESTS YET")
                .font(.pixel(12))
                .foregroundStyle(BRTheme.textPrimary)
            Text(failed
                 ? "We couldn't read your quests from Apple Health. Pull down to try again."
                 : "Pick a reward on your Apple Watch and burn for it — your quest history shows up here.")
                .font(.footnote)
                .foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .brCard()
    }
}

// MARK: - Weekly challenge

/// This week's rotating challenge — the "come back this week" hook. Progress is
/// derived, the pick is deterministic (see `WeeklyChallenge`), and every
/// challenge is a weekly aggregate so rest days never cost anything.
struct WeeklyChallengeCard: View {
    let challenge: WeeklyChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PixelSectionLabel(text: "WEEKLY CHALLENGE")
                Spacer()
                if challenge.isComplete {
                    Text("COMPLETE!")
                        .font(.pixel(7))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 7)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(BRTheme.neonGreen))
                } else {
                    Text(challenge.daysLeftText())
                        .font(.pixel(8))
                        .foregroundStyle(BRTheme.textMuted)
                }
            }

            HStack(spacing: 10) {
                Text(challenge.emoji)
                    .font(.system(size: 24))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.name)
                        .font(.pixel(10))
                        .foregroundStyle(BRTheme.textPrimary)
                    Text(challenge.detail)
                        .font(.footnote)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }

            VStack(spacing: 5) {
                BRProgressBar(
                    fraction: challenge.fraction,
                    fill: challenge.isComplete ? BRTheme.neonGreen : BRTheme.challengeFill,
                    height: 10
                )
                HStack {
                    Text("\(challenge.progress.formatted()) / \(challenge.goal.formatted()) \(challenge.unit)")
                        .font(.pixel(8))
                        .foregroundStyle(challenge.isComplete ? BRTheme.greenFG : BRTheme.orangeFG)
                        .monospacedDigit()
                    Spacer()
                }
            }
        }
        .brCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Weekly challenge: \(challenge.name). \(challenge.detail). " +
            "Progress: \(challenge.progress) of \(challenge.goal) \(challenge.unit)." +
            (challenge.isComplete ? " Complete!" : " \(challenge.daysLeftText().lowercased()).")
        )
    }
}

// MARK: - Week strip

struct WeekStripCard: View {
    let stats: DashboardStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PixelSectionLabel(text: "THIS WEEK")
                Spacer()
                Text("\(stats.questsThisWeek) quests · \(stats.caloriesThisWeek.formatted()) cal")
                    .font(.caption)
                    .foregroundStyle(BRTheme.textMuted)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BRTheme.textMuted)
                    .accessibilityHidden(true)
            }
            HStack(spacing: 7) {
                ForEach(Array(stats.weekDayFlags.enumerated()), id: \.offset) { index, earned in
                    dayCell(
                        symbol: index < stats.weekDaySymbols.count ? stats.weekDaySymbols[index] : "",
                        earned: earned,
                        isToday: index == stats.todayWeekIndex
                    )
                }
            }
        }
        .brCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "This week: \(stats.questsThisWeek) quests, \(stats.caloriesThisWeek) calories burned."
        )
    }

    private func dayCell(symbol: String, earned: Bool, isToday: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(earned ? BRTheme.neonGreen : BRTheme.weekEmpty)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        isToday ? BRTheme.gold : BRTheme.weekBorder,
                        lineWidth: isToday ? 2 : 1
                    )
            )
            .overlay(
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(earned ? BRTheme.onNeonGreen : BRTheme.textMuted)
            )
    }
}

// MARK: - Stat tiles

struct StatTilesRow: View {
    let stats: DashboardStats

    var body: some View {
        HStack(spacing: 10) {
            tile(value: "\(stats.streakDays)", label: "day streak", color: BRTheme.greenFG,
                 fill: BRTheme.tintGreen, spoken: "\(stats.streakDays) day streak")
            tile(value: "\(stats.rewardsWon)", label: "rewards won", color: BRTheme.blueFG,
                 fill: BRTheme.tintBlue, spoken: "\(stats.rewardsWon) rewards won")
            tile(value: BRFormat.compact(stats.allTimeCalories), label: "cal all-time", color: BRTheme.orangeFG,
                 fill: BRTheme.tintOrange, spoken: "\(stats.allTimeCalories) calories all time")
        }
    }

    private func tile(value: String, label: String, color: Color, fill: Color, spoken: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.pixel(16))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(BRTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .brCard(padding: 12, fill: fill)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}

// MARK: - Quest log

struct QuestLogCard: View {
    let quests: [Quest]
    let scores: [UUID: XPBreakdown]
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                PixelSectionLabel(text: "QUEST LOG")
                Spacer()
                Button("See all", action: onSeeAll)
                    .font(.caption)
                    .foregroundStyle(BRTheme.blueFG)
            }
            .padding(.bottom, 4)

            ForEach(Array(quests.enumerated()), id: \.element.id) { index, quest in
                // Each row drills into the quest's detail + XP receipt.
                NavigationLink(value: quest) {
                    QuestLogRow(quest: quest, xp: scores[quest.id]?.total ?? quest.calories)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the quest details and XP receipt.")
                if index < quests.count - 1 {
                    Rectangle().fill(BRTheme.divider).frame(height: 1)
                }
            }
        }
        .brCard()
    }
}

struct QuestLogRow: View {
    let quest: Quest
    let xp: Int

    var body: some View {
        HStack(spacing: 10) {
            Text(quest.emoji)
                .font(.system(size: 22))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(quest.title)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textPrimary)
                    .lineLimit(1)
                Text("\(BRFormat.recentDay(quest.endDate)) · \(quest.activityLabel.capitalized) · \(Int(quest.duration / 60)) min")
                    .font(.caption)
                    .foregroundStyle(BRTheme.textMuted)
            }
            Spacer(minLength: 8)
            Text("+\(xp.formatted()) XP")
                .font(.pixel(11))
                .foregroundStyle(BRTheme.yellowFG)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(BRTheme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(quest.title), \(BRFormat.recentDay(quest.endDate)), \(quest.activityLabel.lowercased()), " +
            "\(Int(quest.duration / 60)) minutes, \(xp) experience points."
        )
    }
}

#Preview("Home — sample") {
    HomeView(model: DashboardViewModel(sample: true), liveManager: LiveQuestManager(), selectedTab: .constant(.home))
}

#Preview("Home — empty") {
    HomeView(model: DashboardViewModel(), liveManager: LiveQuestManager(), selectedTab: .constant(.home))
}

#Preview("Live quest card") {
    LiveQuestCard(snapshot: LiveQuestSnapshot(
        rewardNames: ["Pizza Slice"],
        rewardEmojis: ["🍕"],
        goalCalories: 400,
        caloriesBurned: 212,
        heartRate: 141,
        earnedCount: 0,
        startDate: .now.addingTimeInterval(-745)
    ))
    .padding()
    .background(BRTheme.bg)
}
