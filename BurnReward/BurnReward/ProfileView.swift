import PhotosUI
import SwiftUI
import UIKit

/// The player's character sheet. Everything below the name is derived live from
/// the HealthKit quest list (class affinity, records, trophies, lifetime totals),
/// so it needs no separate store and a reinstall rebuilds it exactly.
struct ProfileView: View {
    @ObservedObject var model: DashboardViewModel
    /// The guild account — threaded through to Settings so account deletion
    /// (Apple 5.1.1(v)) can tear down the session. Optional so previews and any
    /// legacy sheet presentation without a guild still compile.
    var guild: GuildManager? = nil
    /// True when living on the CHARACTER tab (custom header, Settings gear,
    /// no Done); false for legacy sheet presentation.
    var presentedAsTab: Bool = false
    @AppStorage("br.displayName") private var displayName = ""
    @AppStorage("br.avatarJPEG") private var avatarData = Data()
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedBadge: Badge?
    @State private var showSettings = false
    @State private var demoReceiptQuest: Quest?   // -BRDemoQuestReceipt: presents a quest receipt for screenshots
    @State private var demoShareCard: ShareCardKind?  // -BRDemoShareCard[Badge]: presents the share card for screenshots
    @Environment(\.dismiss) private var dismiss

    /// Identity stamped onto share cards (level + rank + optional name).
    private var shareContext: ShareContext {
        let level = model.stats.levelProgress.level
        return ShareContext(level: level,
                            rankTitle: LevelEngine.title(for: level),
                            playerName: displayName)
    }

    private var affinities: [ClassAffinity] { ClassAffinity.all(for: model.quests) }
    private var records: [PersonalRecord] { model.records }
    private var badges: [Badge] {
        let dates = model.badgeEarnedDates
        return BadgeCatalog.all(for: model.quests, stats: model.stats)
            .map { $0.withEarnedDate(dates[$0.id]) }
    }

    var body: some View {
        let stats = model.stats
        NavigationStack {
            VStack(spacing: 0) {
                if presentedAsTab {
                    BRTabHeader("CHARACTER") {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(BRTheme.textMuted)
                                .frame(minWidth: 44, minHeight: 30, alignment: .trailing)
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                ZStack {
                    BRTheme.bg.ignoresSafeArea()
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack(spacing: 18) {
                                identityPlate(progress: stats.levelProgress)
                                classAffinitySection
                                recordsSection
                                trophyCase
                                    .id("trophyCase")
                                lifetimeSection(stats: stats)
                                perkTreeTeaser
                            }
                            .padding(16)
                            .onAppear {
                                // `-BRScrollToTrophies`: jump to the trophy case
                                // (simulator screenshots — no scroll automation).
                                if ProcessInfo.processInfo.arguments.contains("-BRScrollToTrophies") {
                                    proxy.scrollTo("trophyCase", anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            .background(BRTheme.bg)
            .toolbar(presentedAsTab ? .hidden : .visible, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView(model: model, guild: guild) }
            .navigationDestination(for: Quest.self) { quest in
                QuestDetailView(quest: quest, xp: model.xpBreakdown(for: quest),
                                recordKinds: model.recordKinds(for: quest),
                                shareContext: shareContext)
            }
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailSheet(badge: badge, shareContext: shareContext)
            }
            .sheet(item: $demoReceiptQuest) { quest in
                NavigationStack {
                    QuestDetailView(quest: quest, xp: model.xpBreakdown(for: quest),
                                    recordKinds: model.recordKinds(for: quest),
                                    shareContext: shareContext)
                }
            }
            .sheet(item: $demoShareCard) { kind in
                ShareCardSheet(kind: kind,
                               level: shareContext.level,
                               rankTitle: shareContext.rankTitle,
                               playerName: shareContext.playerName)
            }
            .onAppear {
                // `-BRDemoBadgeSheet` / `-BRDemoBadgeSheetEarned` open a locked /
                // earned ladder badge at launch (simulator screenshots — there's
                // no tap automation).
                let arguments = ProcessInfo.processInfo.arguments
                if selectedBadge == nil {
                    if arguments.contains("-BRDemoBadgeSheetEarned") {
                        selectedBadge = badges.first { $0.id == "inferno" }
                    } else if arguments.contains("-BRDemoBadgeSheet") {
                        selectedBadge = badges.first { $0.id == "dragon_slayer" }
                    }
                }
                if arguments.contains("-BRDemoQuestReceipt"), demoReceiptQuest == nil {
                    demoReceiptQuest = model.quests.first { $0.earned }
                }
                // The outside-workout receipt: 0.8 base rate, SIDE QUEST chip,
                // Recorded by + Distance rows, and no quest-complete bonus.
                if arguments.contains("-BRDemoOutsideReceipt"), demoReceiptQuest == nil {
                    demoReceiptQuest = model.quests.first { $0.isOutside }
                }
                // `-BRDemoShareCard` / `-BRDemoShareCardBadge` present the social
                // share card (quest / badge variant) for simulator screenshots.
                if demoShareCard == nil {
                    if arguments.contains("-BRDemoShareCardBadge") {
                        if let badge = badges.first(where: { $0.id == "inferno" && $0.earned }) {
                            demoShareCard = .badge(badge)
                        }
                    } else if arguments.contains("-BRDemoShareCard") {
                        if let quest = model.quests.first(where: { $0.earned && $0.goalCalories != nil }) {
                            demoShareCard = .quest(quest, xpTotal: model.xpBreakdown(for: quest).total)
                        }
                    }
                }
                if presentedAsTab, arguments.contains("-BRStartOnSettings") {
                    showSettings = true
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let jpeg = AvatarPhoto.resizedJPEG(from: data, maxDimension: 256) {
                        avatarData = jpeg
                    }
                    photoItem = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CHARACTER")
                        .font(.pixel(12))
                        .foregroundStyle(BRTheme.greenFG)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(BRTheme.blueFG)
                }
            }
        }
    }

    // MARK: - Identity plate

    private func identityPlate(progress: LevelEngine.Progress) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    AvatarBadge(
                        name: displayName,
                        size: 64,
                        photoData: avatarData.isEmpty ? nil : avatarData
                    )
                    .overlay(Circle().strokeBorder(BRTheme.gold, lineWidth: 2))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(BRTheme.onNeonGreen)
                            .padding(5)
                            .background(Circle().fill(BRTheme.neonGreen))
                            .offset(x: 2, y: 2)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change profile picture")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("Your name", text: $displayName)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(BRTheme.textPrimary)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .lineLimit(1)
                            // Width = min(text, 165): hug a short name so the pencil
                            // sits right beside it, but cap + clip a long one so it
                            // truncates instead of shoving the LVL badge off the
                            // plate. `fixedSize` must be OUTERMOST — it resolves the
                            // greedy `maxWidth` frame down to the clamped ideal.
                            .frame(maxWidth: 165, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                            .clipped()
                            .accessibilityLabel("Your name")
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(BRTheme.textMuted)
                            .accessibilityHidden(true)
                    }
                    Text(progress.title)
                        .font(.pixel(9))
                        .foregroundStyle(BRTheme.greenFG)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    Text("LVL")
                        .font(.pixel(7))
                        .foregroundStyle(BRTheme.mutedOnDark)
                    Text("\(progress.level)")
                        .font(.pixel(14))
                        .foregroundStyle(BRTheme.expFill)
                }
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(BRTheme.darkIsland))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(BRTheme.gold, lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Level \(progress.level)")
            }

            VStack(spacing: 6) {
                BRProgressBar(fraction: progress.fraction, fill: BRTheme.xpFill, height: 10)
                HStack {
                    Text("\(model.stats.totalXP.formatted()) XP")
                        .font(.pixel(8))
                        .foregroundStyle(BRTheme.yellowFG)
                    Spacer()
                    Text("\(progress.xpIntoLevel.formatted()) / \(progress.xpLevelSpan.formatted()) to LVL \(progress.level + 1)")
                        .font(.caption2)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(model.stats.totalXP) total experience points. " +
                "\(progress.xpIntoLevel) of \(progress.xpLevelSpan) to level \(progress.level + 1)."
            )
        }
        .brCard()
    }

    // MARK: - Class affinity

    private var classAffinitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionLabel(text: "CLASS AFFINITY")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: affinities.count),
                spacing: 6
            ) {
                ForEach(affinities) { affinity in
                    classTile(affinity)
                }
            }
        }
    }

    private func classTile(_ affinity: ClassAffinity) -> some View {
        VStack(spacing: 5) {
            Text(affinity.emoji)
                .font(.system(size: 18))
                .accessibilityHidden(true)
            Text("\(affinity.count)")
                .font(.pixel(11))
                .foregroundStyle(affinity.isMain ? BRTheme.greenFG : BRTheme.textPrimary)
            Text(affinity.name)
                .font(.caption2)
                .foregroundStyle(BRTheme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 3)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BRTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(affinity.isMain ? BRTheme.greenFG : BRTheme.cardBorder,
                                      lineWidth: affinity.isMain ? 1.5 : 1)
                )
        )
        .overlay(alignment: .top) {
            if affinity.isMain {
                Text("MAIN")
                    .font(.pixel(6))
                    .foregroundStyle(BRTheme.onNeonGreen)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(BRTheme.neonGreen))
                    .offset(y: -7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(affinity.name), \(affinity.count) quest\(affinity.count == 1 ? "" : "s")\(affinity.isMain ? ", your main class" : "")")
    }

    // MARK: - Records

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionLabel(text: "RECORDS")
            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    recordRow(record)
                    if index < records.count - 1 {
                        Rectangle().fill(BRTheme.divider).frame(height: 1).padding(.leading, 42)
                    }
                }
            }
            .brCard(padding: 0)
        }
    }

    @ViewBuilder
    private func recordRow(_ record: PersonalRecord) -> some View {
        if let quest = record.quest {
            NavigationLink(value: quest) {
                recordRowContent(record, showChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            recordRowContent(record, showChevron: false)
        }
    }

    private func recordRowContent(_ record: PersonalRecord, showChevron: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: recordIcon(record.kind))
                .font(.system(size: 14))
                .foregroundStyle(recordColor(record.kind))
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(recordTitle(record.kind))
                    .font(.subheadline)
                    .foregroundStyle(BRTheme.textPrimary)
                Text(record.detail)
                    .font(.caption2)
                    .foregroundStyle(BRTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(record.value)
                .font(.pixel(9))
                .foregroundStyle(BRTheme.yellowFG)
                .monospacedDigit()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(BRTheme.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recordTitle(record.kind)): \(record.value). \(record.detail)")
        .accessibilityAddTraits(showChevron ? .isButton : [])
    }

    private func recordTitle(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .burn:      "Biggest burn"
        case .duration:  "Longest quest"
        case .steps:     "Most steps"
        case .heartRate: "Highest avg HR"
        case .streak:    "Best streak"
        }
    }

    private func recordIcon(_ kind: PersonalRecord.Kind) -> String {
        switch kind {
        case .burn:      "flame.fill"
        case .duration:  "clock.fill"
        case .steps:     "figure.walk"
        case .heartRate: "heart.fill"
        case .streak:    "calendar"
        }
    }

    private func recordColor(_ kind: PersonalRecord.Kind) -> Color {
        switch kind {
        case .burn:      BRTheme.orangeFG
        case .duration:  BRTheme.blueFG
        case .steps:     BRTheme.greenFG
        case .heartRate: BRTheme.alertRed
        case .streak:    BRTheme.greenFG
        }
    }

    // MARK: - Trophy case

    private var trophyCase: some View {
        let sorted = badges.filter(\.earned) + badges.filter { !$0.earned }
        let earnedCount = badges.filter(\.earned).count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                PixelSectionLabel(text: "TROPHY CASE")
                Spacer()
                Text("\(earnedCount) of \(badges.count)")
                    .font(.caption2)
                    .foregroundStyle(BRTheme.textMuted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                ForEach(sorted) { badge in
                    badgeTile(badge)
                }
            }
            .brCard(padding: 14)
        }
    }

    private func badgeTile(_ badge: Badge) -> some View {
        Button {
            selectedBadge = badge
        } label: {
            VStack(spacing: 5) {
                // Ring state: earned = solid gold; in progress = faint track +
                // gold arc (the "unfinished business" cue); untouched = dashed.
                let ringFraction = badge.earned ? 0 : (badge.progress?.fraction ?? 0)
                // Drawn medallion: full color when earned; a grayed "ghost"
                // when locked (see the whole collection, chase the color).
                // The gold arc still wraps in-progress ones.
                if let art = UIImage(named: "badge_\(badge.id)") {
                    ZStack {
                        Image(uiImage: art)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .saturation(badge.earned ? 1 : 0)
                            .opacity(badge.earned ? 1 : 0.35)
                        if ringFraction > 0 {
                            Circle()
                                .trim(from: 0, to: ringFraction)
                                .stroke(BRTheme.gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 50, height: 50)
                        }
                    }
                    .frame(width: 50, height: 50)
                } else {
                ZStack {
                    Circle()
                        .fill(badge.earned ? BRTheme.gold.opacity(0.15) : Color.clear)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().strokeBorder(
                                badge.earned ? BRTheme.gold : BRTheme.weekBorder,
                                style: badge.earned || ringFraction > 0
                                    ? StrokeStyle(lineWidth: 1)
                                    : StrokeStyle(lineWidth: 1, dash: [3])
                            )
                        )
                    if ringFraction > 0 {
                        Circle()
                            .trim(from: 0, to: ringFraction)
                            .stroke(BRTheme.gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                    }
                    if badge.earned {
                        Text(badge.emoji).font(.system(size: 19))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(BRTheme.textMuted)
                    }
                }
                }
                Text(badge.name)
                    .font(.caption2)
                    .foregroundStyle(badge.earned ? BRTheme.textPrimary : BRTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            badge.earned
                ? "\(badge.name), earned. \(badge.requirement)"
                : "\(badge.name), locked. \(badge.requirement)" + (
                    badge.progress.map { ". \($0.current) of \($0.target) \($0.unit)" } ?? ""
                )
        )
        .accessibilityHint("Shows badge details.")
    }

    // MARK: - Lifetime

    private func lifetimeSection(stats: DashboardStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelSectionLabel(text: "LIFETIME")
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    lifetimeTile(value: "\(model.quests.filter(\.earned).count)", label: "quests earned", color: BRTheme.greenFG, fill: BRTheme.tintGreen)
                    lifetimeTile(value: "\(stats.rewardsWon)", label: "rewards won", color: BRTheme.blueFG, fill: BRTheme.tintBlue)
                }
                HStack(spacing: 10) {
                    lifetimeTile(value: BRFormat.compact(stats.allTimeCalories), label: "cal all-time", color: BRTheme.orangeFG, fill: BRTheme.tintOrange)
                    lifetimeTile(value: BRFormat.compact(stats.totalXP), label: "total XP", color: BRTheme.yellowFG, fill: BRTheme.tintYellow)
                }
            }
        }
    }

    private func lifetimeTile(value: String, label: String, color: Color, fill: Color) -> some View {
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
        .accessibilityElement(children: .combine)
    }

    // MARK: - Perk tree teaser

    private var perkTreeTeaser: some View {
        VStack(spacing: 10) {
            PerkTreeGlyph()
                .frame(height: 60)
                .opacity(0.5)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(BRTheme.gold)
                Text("PERK TREE")
                    .font(.pixel(9))
                    .foregroundStyle(BRTheme.textPrimary)
            }
            Text("Locked · coming in a future update")
                .font(.caption2)
                .foregroundStyle(BRTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .brCard(padding: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Perk tree. Locked, coming in a future update.")
    }
}

/// Compact badge inspector: medallion, earned/locked state, the requirement,
/// and — for the quantifiable ladders — progress toward the target, so a
/// locked badge reads as a goal instead of a mystery.
private struct BadgeDetailSheet: View {
    let badge: Badge
    /// Player identity for the share card; nil hides the share button.
    var shareContext: ShareContext? = nil
    @State private var showShareCard = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            BRTheme.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                Group {
                    // The art IS the medallion — grayed ghost until earned.
                    if let art = UIImage(named: "badge_\(badge.id)") {
                        Image(uiImage: art)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 130, height: 130)
                            .saturation(badge.earned ? 1 : 0)
                            .opacity(badge.earned ? 1 : 0.4)
                    } else {
                        ZStack {
                            Circle()
                                .fill(badge.earned ? BRTheme.gold.opacity(0.15) : Color.clear)
                                .frame(width: 84, height: 84)
                                .overlay(
                                    Circle().strokeBorder(
                                        badge.earned ? BRTheme.gold : BRTheme.weekBorder,
                                        style: badge.earned
                                            ? StrokeStyle(lineWidth: 1.5)
                                            : StrokeStyle(lineWidth: 1.5, dash: [4])
                                    )
                                )
                            if badge.earned {
                                Text(badge.emoji).font(.system(size: 40))
                            } else {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(BRTheme.textMuted)
                            }
                        }
                    }
                }
                .accessibilityHidden(true)

                Text(badge.name.uppercased())
                    .font(.pixel(13))
                    .foregroundStyle(BRTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                if badge.earned {
                    Text("EARNED")
                        .font(.pixel(9))
                        .foregroundStyle(BRTheme.onNeonGreen)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BRTheme.neonGreen))
                } else {
                    Text("LOCKED")
                        .font(.pixel(9))
                        .foregroundStyle(BRTheme.textMuted)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BRTheme.weekBorder, lineWidth: 1))
                }

                Text(badge.requirement)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .multilineTextAlignment(.center)

                if let progress = badge.progress {
                    VStack(spacing: 6) {
                        BRProgressBar(
                            fraction: progress.fraction,
                            // Green = done (matches the EARNED pill); gold = climbing.
                            fill: badge.earned ? BRTheme.neonGreen : BRTheme.expFill,
                            height: 10
                        )
                        Text("\(progress.current.formatted()) / \(progress.target.formatted()) \(progress.unit)")
                            .font(.pixel(8))
                            .foregroundStyle(badge.earned ? BRTheme.greenFG : BRTheme.yellowFG)
                            .monospacedDigit()
                    }
                    .padding(.top, 2)
                }

                // Earned badges get a flavor line and the date they were first
                // satisfied (both derived; the +XP reward is deferred to the Ember
                // Tree, where badge XP belongs to the economy pass).
                if badge.earned {
                    VStack(spacing: 8) {
                        if !badge.flavor.isEmpty {
                            detailRow(icon: "target", tint: BRTheme.greenFG, label: "CHALLENGE",
                                      text: badge.flavor, showCheck: true)
                        }
                        if let earnedDate = badge.earnedDate {
                            detailRow(icon: "calendar", tint: BRTheme.blueFG, label: "EARNED ON",
                                      text: earnedDate.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    .padding(.top, 6)
                }

                // Earned trophies can leave the building — social P0.
                if badge.earned, shareContext != nil {
                    ShareWinButton { showShareCard = true }
                        .padding(.top, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
        }
        .sheet(isPresented: $showShareCard) {
            if let shareContext {
                ShareCardSheet(kind: .badge(badge),
                               level: shareContext.level,
                               rankTitle: shareContext.rankTitle,
                               playerName: shareContext.playerName)
            }
        }
        .presentationDetents([.height(badge.earned ? 614 : 400)])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isSummaryElement)
    }

    private var accessibilitySummary: String {
        var parts = ["\(badge.name), \(badge.earned ? "earned" : "locked"). \(badge.requirement)."]
        if let progress = badge.progress {
            parts.append("Progress: \(progress.current) of \(progress.target) \(spokenUnit(progress.unit)).")
        }
        if badge.earned, let date = badge.earnedDate {
            parts.append("Earned \(date.formatted(date: .abbreviated, time: .omitted)).")
        }
        return parts.joined(separator: " ")
    }

    private func spokenUnit(_ unit: String) -> String {
        switch unit {
        case "cal": "calories"
        case "min": "minutes"
        default:    unit
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, tint: Color, label: String, text: String,
                           showCheck: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.pixel(8))
                    .foregroundStyle(tint)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if showCheck {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(BRTheme.greenFG)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(BRTheme.card))
    }
}

/// A faint branching-node glyph that hints at the future skill tree without
/// promising specifics. Purely decorative.
private struct PerkTreeGlyph: View {
    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let xs = [0.12, 0.4, 0.62, 0.88].map { $0 * size.width }
            let ys = (top: size.height * 0.18, bottom: size.height * 0.82)
            let muted = BRTheme.textMuted
            let gold = BRTheme.gold

            func line(_ a: CGPoint, _ b: CGPoint) {
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                context.stroke(path, with: .color(muted), lineWidth: 1)
            }
            let root = CGPoint(x: xs[0], y: midY)
            let up = CGPoint(x: xs[1], y: ys.top)
            let down = CGPoint(x: xs[1], y: ys.bottom)
            let mid = CGPoint(x: xs[2], y: midY)
            let up2 = CGPoint(x: xs[3], y: ys.top)
            let down2 = CGPoint(x: xs[3], y: ys.bottom)

            line(root, up); line(root, down)
            line(up, mid); line(down, mid)
            line(mid, up2); line(mid, down2)

            func node(_ p: CGPoint, filled: Bool) {
                let r: CGFloat = filled ? 6 : 5
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                if filled {
                    context.fill(Path(ellipseIn: rect), with: .color(gold))
                } else {
                    context.stroke(Path(ellipseIn: rect), with: .color(muted), lineWidth: 1.5)
                }
            }
            node(root, filled: true)
            [up, down, mid, up2, down2].forEach { node($0, filled: false) }
        }
    }
}

/// Downscales the picked photo so the stored avatar stays a few dozen KB —
/// it lives in UserDefaults and never leaves the device.
private enum AvatarPhoto {
    static func resizedJPEG(from data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(maxDimension / longest, 1)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

#Preview("Character sheet") {
    ProfileView(model: DashboardViewModel(sample: true))
}
