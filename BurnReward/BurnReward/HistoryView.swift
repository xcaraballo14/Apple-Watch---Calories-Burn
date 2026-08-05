import Charts
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: DashboardViewModel
    @AppStorage("br.displayName") private var displayName = ""

    /// Identity stamped onto share cards (level + rank + optional name).
    private var shareContext: ShareContext {
        let level = model.stats.levelProgress.level
        return ShareContext(level: level,
                            rankTitle: LevelEngine.title(for: level),
                            playerName: displayName)
    }
    /// nil = ALL. Otherwise a class key ("RUN"/"WALK"/"BIKE"/"LIFT"/"OTHER"),
    /// bucketed exactly like the character sheet's class affinity.
    @State private var classFilter: String?

    private struct MonthSection: Identifiable {
        let id: Date
        let title: String
        let quests: [Quest]
    }

    /// The same bucketing the affinity chips use, so a chip and its filtered
    /// list can never disagree.
    private func classKey(_ quest: Quest) -> String {
        CharacterClass.coreOrder.contains(quest.activityLabel) ? quest.activityLabel : "OTHER"
    }

    /// One chip per class the player has actually logged (ALL is prepended in
    /// the view). Reuses the affinity counts so History and the sheet match.
    private var classChips: [ClassAffinity] {
        ClassAffinity.all(for: model.quests).filter { $0.count > 0 }
    }

    private var filteredQuests: [Quest] {
        guard let classFilter else { return model.quests }
        return model.quests.filter { classKey($0) == classFilter }
    }

    private var sections: [MonthSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredQuests) { quest in
            calendar.dateInterval(of: .month, for: quest.endDate)?.start
                ?? calendar.startOfDay(for: quest.endDate)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { key, quests in
                MonthSection(
                    id: key,
                    title: key.formatted(.dateTime.month(.wide).year()).uppercased(),
                    quests: quests.sorted { $0.endDate > $1.endDate }
                )
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                BRTabHeader("QUEST LOG")
                if !model.quests.isEmpty {
                    filterBar
                    Rectangle().fill(BRTheme.divider).frame(height: 1)
                }
                content
            }
            .background(BRTheme.bg)
            // Custom header instead of a system nav bar — content starts
            // immediately (pushed quest details keep their own nav bars).
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Quest.self) {
                QuestDetailView(quest: $0, xp: model.xpBreakdown(for: $0),
                                recordKinds: model.recordKinds(for: $0),
                                shareContext: shareContext)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.quests.isEmpty {
            // Wrapped in a ScrollView so pull-to-refresh works with no rows —
            // the failed-fetch copy tells people to pull down to retry.
            ScrollView {
                emptyState.frame(maxWidth: .infinity, minHeight: 420)
            }
            .refreshable { await model.refresh() }
        } else {
            List {
                // The weekly chart is an all-activity overview; drop it while a
                // class filter is on so the chart never contradicts the list.
                if classFilter == nil {
                    Section {
                        WeeklyBurnCard(buckets: model.weeklyBuckets)
                            .listRowBackground(BRTheme.card)
                            .listRowSeparator(.hidden)
                    }
                }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.quests) { quest in
                            NavigationLink(value: quest) {
                                HistoryRow(
                                    quest: quest,
                                    xp: model.scores[quest.id]?.total ?? quest.calories,
                                    isRecordHolder: !model.recordKinds(for: quest).isEmpty
                                )
                            }
                            .listRowBackground(BRTheme.card)
                            .listRowSeparatorTint(BRTheme.divider)
                        }
                    } header: {
                        Text(section.title)
                            .font(.pixel(11))
                            .foregroundStyle(BRTheme.textMuted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 8, for: .scrollContent)
            .refreshable { await model.refresh() }
        }
    }

    // MARK: - Class filter

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(key: nil, emoji: nil, name: "ALL", count: model.quests.count)
                ForEach(classChips) { affinity in
                    filterChip(key: affinity.label, emoji: affinity.emoji, name: affinity.name, count: affinity.count)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
    }

    private func filterChip(key: String?, emoji: String?, name: String, count: Int) -> some View {
        let selected = classFilter == key
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { classFilter = key }
        } label: {
            HStack(spacing: 5) {
                if let emoji {
                    Text(emoji).font(.system(size: 13)).accessibilityHidden(true)
                }
                Text(name).font(.pixel(9))
                Text("\(count)").font(.pixel(9)).opacity(0.7)
            }
            .monospacedDigit()
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .foregroundStyle(selected ? BRTheme.onNeonGreen : BRTheme.textPrimary)
            .background(Capsule().fill(selected ? BRTheme.neonGreen : BRTheme.card))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : BRTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(count) quest\(count == 1 ? "" : "s")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var emptyState: some View {
        // A thrown read (not a genuinely empty account) gets its own copy so a
        // transient Health failure doesn't masquerade as "you've done nothing."
        let failed = model.state == .failed
        return VStack(spacing: 10) {
            Image(systemName: failed ? "exclamationmark.arrow.circlepath" : "list.bullet.rectangle")
                .font(.system(size: 28))
                .foregroundStyle(BRTheme.textMuted)
                .accessibilityHidden(true)
            Text(failed ? "COULDN'T LOAD" : "NO QUESTS YET")
                .font(.pixel(12))
                .foregroundStyle(BRTheme.textPrimary)
            Text(failed
                 ? "We couldn't read your quests from Apple Health. Pull down to try again."
                 : "Every quest you finish on your Apple Watch lands here.")
                .font(.footnote)
                .foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WeeklyBurnCard: View {
    let buckets: [DashboardViewModel.WeekBucket]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PixelSectionLabel(text: "WEEKLY BURN")
                Spacer()
                Text("LAST 8 WEEKS")
                    .font(.pixel(9))
                    .foregroundStyle(BRTheme.textMuted)
            }
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Week", Self.weekLabel(bucket.id)),
                    y: .value("Calories", bucket.calories)
                )
                .foregroundStyle(isCurrentWeek(bucket.id) ? BRTheme.gold : BRTheme.greenFG)
                .cornerRadius(3)
                .accessibilityLabel("Week of \(bucket.id.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityValue("\(bucket.calories) calories")
            }
            .chartXScale(domain: buckets.map { Self.weekLabel($0.id) })
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(BRTheme.divider)
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 6)
    }

    private func isCurrentWeek(_ week: Date) -> Bool {
        Calendar.current.isDate(week, equalTo: .now, toGranularity: .weekOfYear)
    }

    private static func weekLabel(_ week: Date) -> String {
        week.formatted(.dateTime.month(.defaultDigits).day())
    }
}

struct HistoryRow: View {
    let quest: Quest
    let xp: Int
    /// True when this quest currently holds a personal record (burn, duration,
    /// or steps) — shows the gold RECORD tag. Specifics live in the detail view.
    var isRecordHolder: Bool = false

    /// A quest's title is its reward, so the workout type belongs in the
    /// subtitle. An outside workout's title *is* the type, so the slot goes to
    /// the source instead — the fact a player is actually checking for ("did it
    /// see my Garmin?").
    ///
    /// The source goes **last** deliberately. It reads better in the middle, but
    /// this line is `lineLimit(1)` and real source names are long — "Garmin
    /// Connect" pushed the calories off the end entirely. Trailing means the
    /// truncation eats the app name, which the player can still recognise from
    /// its first few letters, instead of the numbers they came to see.
    private var subtitle: String {
        let day = quest.endDate.formatted(.dateTime.month(.abbreviated).day())
        let metrics = "\(Int(quest.duration / 60)) min · \(quest.calories) cal"
        if quest.isOutside, let sourceName = quest.sourceName {
            return "\(day) · \(metrics) · \(sourceName)"
        }
        return "\(day) · \(quest.activityLabel.capitalized) · \(metrics)"
    }

    private var accessibilityText: String {
        let date = quest.endDate.formatted(date: .abbreviated, time: .omitted)
        var parts = [
            quest.title,
            date,
            quest.activityLabel.lowercased(),
            "\(quest.calories) calories",
            "\(xp) experience points",
        ]
        if let sourceName = quest.sourceName { parts.append("recorded by \(sourceName)") }
        if isRecordHolder { parts.append("current record holder") }
        if quest.isOutside {
            parts.append("side quest")
        } else if !quest.earned {
            parts.append("unfinished")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(quest.emoji)
                .font(.system(size: 30))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(quest.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BRTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text("+\(xp.formatted()) XP")
                    .font(.pixel(10))
                    .foregroundStyle(BRTheme.yellowFG)
                if isRecordHolder {
                    Text("🏆 RECORD")
                        .font(.pixel(7))
                        .foregroundStyle(BRTheme.gold)
                }
                // An outside workout isn't unfinished — it was a whole workout
                // that simply wasn't run as a quest. Saying UNFINISHED here
                // would read as a failure the player never had.
                if quest.isOutside {
                    Text("SIDE QUEST")
                        .font(.pixel(7))
                        .foregroundStyle(BRTheme.blueFG)
                } else if !quest.earned {
                    Text("UNFINISHED")
                        .font(.pixel(8))
                        .foregroundStyle(BRTheme.textMuted)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

struct QuestDetailView: View {
    let quest: Quest
    let xp: XPBreakdown
    /// Records this quest currently holds — rendered as gold stamps.
    var recordKinds: [PersonalRecord.Kind] = []
    /// Player identity for the share card; nil hides the share button.
    var shareContext: ShareContext? = nil
    @State private var showShareCard = false

    private func recordStamp(_ kind: PersonalRecord.Kind) -> (emoji: String, label: String)? {
        switch kind {
        case .burn:     ("🔥", "BIGGEST BURN")
        case .duration: ("⏱️", "LONGEST QUEST")
        case .steps:    ("👣", "MOST STEPS")
        default:        nil
        }
    }

    var body: some View {
        ZStack {
            BRTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text(quest.emoji)
                        .font(.system(size: 64))
                        .accessibilityHidden(true)
                    Text(quest.title)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(BRTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    if quest.isOutside {
                        Text("SIDE QUEST")
                            .font(.pixel(11))
                            .foregroundStyle(BRTheme.blueFG)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(BRTheme.blueFG.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(BRTheme.blueFG, lineWidth: 1)
                            )
                    } else if quest.earned {
                        Text("EARNED")
                            .font(.pixel(11))
                            .foregroundStyle(BRTheme.onNeonGreen)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(BRTheme.neonGreen))
                    } else {
                        Text("UNFINISHED")
                            .font(.pixel(11))
                            .foregroundStyle(BRTheme.textMuted)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(BRTheme.weekBorder, lineWidth: 1))
                    }

                    // Gold stamps for every record this quest currently holds.
                    let stamps = recordKinds.compactMap(recordStamp)
                    if !stamps.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(stamps, id: \.label) { stamp in
                                HStack(spacing: 4) {
                                    Text(stamp.emoji).font(.system(size: 11))
                                    Text(stamp.label).font(.pixel(8))
                                }
                                .foregroundStyle(BRTheme.gold)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(BRTheme.gold.opacity(0.12))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(BRTheme.gold, lineWidth: 1)
                                )
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Current record: \(stamp.label.lowercased())")
                            }
                        }
                    }

                    VStack(spacing: 0) {
                        detailRow("Date", quest.endDate.formatted(date: .abbreviated, time: .shortened))
                        detailRow("Workout", quest.activityLabel.capitalized)
                        if let sourceName = quest.sourceName {
                            detailRow("Recorded by", sourceName)
                        }
                        if let distanceText = quest.distanceText {
                            detailRow("Distance", distanceText)
                        }
                        detailRow("Duration", BRFormat.duration(quest.duration))
                        detailRow("Avg heart rate", quest.averageHeartRate.map { "\($0) BPM" } ?? "—")
                        detailRow("Steps", quest.steps.map { $0.formatted() } ?? "—")
                        if let goal = quest.goalCalories {
                            detailRow("Calories burned", "\(quest.calories)")
                            detailRow("Goal", "\(goal) cal", isLast: true)
                        } else {
                            detailRow("Calories burned", "\(quest.calories)", isLast: true)
                        }
                    }
                    .brCard(padding: 0)

                    VStack(alignment: .leading, spacing: 0) {
                        PixelSectionLabel(text: "XP BREAKDOWN")
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                        detailRow("Base · \(xp.sourceRate.formatted()) XP per calorie", "\(xp.ratedBase)")
                        if xp.typeXP > 0 {
                            detailRow("Strength training ×\(xp.typeFactor.formatted())", "+\(xp.typeXP)", valueColor: BRTheme.orangeFG)
                        }
                        if xp.intensityXP > 0 {
                            detailRow("Intensity ×\(xp.intensityFactor.formatted())", "+\(xp.intensityXP)", valueColor: BRTheme.orangeFG)
                        }
                        if xp.earnedBonus > 0 {
                            detailRow("Quest complete", "+\(xp.earnedBonus)", valueColor: BRTheme.greenFG)
                        }
                        if xp.firstOfDayBonus > 0 {
                            detailRow("First quest of the day", "+\(xp.firstOfDayBonus)", valueColor: BRTheme.blueFG)
                        }
                        if xp.precisionBonus > 0 {
                            detailRow("Precision landing", "+\(xp.precisionBonus)", valueColor: BRTheme.yellowFG)
                        }
                        HStack {
                            Text("TOTAL")
                                .font(.pixel(11))
                                .foregroundStyle(BRTheme.textPrimary)
                            Spacer()
                            Text("+\(xp.total.formatted()) XP")
                                .font(.pixel(12))
                                .foregroundStyle(BRTheme.yellowFG)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .accessibilityElement(children: .combine)

                        // States the rule instead of docking a line for it —
                        // the gap becomes a reason to run a quest rather than a
                        // punishment for training outside the app.
                        if quest.isOutside {
                            HStack(spacing: 6) {
                                Text("⚔️").font(.system(size: 11))
                                Text("Run a quest in BurnReward to earn at the full rate.")
                                    .font(.caption)
                                    .foregroundStyle(BRTheme.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 14)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .brCard(padding: 0)

                    // Earned wins can leave the building — social P0.
                    if quest.earned, shareContext != nil {
                        ShareWinButton { showShareCard = true }
                            .padding(.top, 2)
                    }
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareCard) {
            if let shareContext {
                ShareCardSheet(kind: .quest(quest, xpTotal: xp.total),
                               level: shareContext.level,
                               rankTitle: shareContext.rankTitle,
                               playerName: shareContext.playerName)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String, valueColor: Color = BRTheme.textPrimary, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                Spacer()
                Text(value)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            if !isLast {
                Rectangle().fill(BRTheme.divider).frame(height: 1).padding(.leading, 14)
            }
        }
    }
}

#Preview("History") {
    HistoryView(model: DashboardViewModel(sample: true))
}
