import SwiftUI
import UIKit

/// What the player is sharing. Presented from the quest receipt (quest) or
/// the badge detail sheet (badge); also drives the demo launch flags.
enum ShareCardKind: Identifiable {
    case quest(Quest, xpTotal: Int)
    case badge(Badge)

    var id: String {
        switch self {
        case .quest(let quest, _): "quest-\(quest.id)"
        case .badge(let badge):    "badge-\(badge.id)"
        }
    }
}

/// Player identity the share card stamps into its signature line — built by
/// any surface that owns the dashboard model.
struct ShareContext {
    let level: Int
    let rankTitle: String
    let playerName: String
}

/// The green entry button shared by every surface that can open the share
/// card (quest receipt, badge detail sheet). Earned wins only — callers gate.
struct ShareWinButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("SHARE THIS WIN", systemImage: "square.and.arrow.up")
                .font(.pixel(10))
                .foregroundStyle(BRTheme.onNeonGreen)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BRTheme.neonGreen)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share this win")
        .accessibilityHint("Opens a shareable card of this achievement.")
    }
}

/// The shareable graphic itself — social's P0. Rendered on-device (later via
/// `ImageRenderer` for the share sheet), fully derived from local data, no
/// backend. Always dark: a share card must look identical wherever it lands,
/// so the card pins its own color scheme instead of following the device.
struct ShareCardView: View {
    let kind: ShareCardKind
    let level: Int
    let rankTitle: String
    let playerName: String

    var body: some View {
        VStack(spacing: 0) {
            Text("BURNREWARD")
                .font(.pixel(9))
                .foregroundStyle(BRTheme.greenFG)
                .padding(.bottom, 14)

            switch kind {
            case .quest(let quest, let xpTotal): questBody(quest, xpTotal: xpTotal)
            case .badge(let badge):              badgeBody(badge)
            }

            Rectangle()
                .fill(BRTheme.divider)
                .frame(height: 1)
                .padding(.vertical, 12)

            Text(playerLine)
                .font(.pixel(8))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("SWEAT NOW. FEAST LATER.")
                .font(.pixel(6))
                .foregroundStyle(BRTheme.mutedOnDark)
                .padding(.top, 7)
        }
        .padding(22)
        .frame(width: 330)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BRTheme.darkIsland)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(BRTheme.gold, lineWidth: 2)
                )
        )
        .environment(\.colorScheme, .dark)  // the card never follows the device theme
        .accessibilityElement(children: .combine)
    }

    private var playerLine: String {
        let rank = "LVL \(level) · \(rankTitle)"
        let name = playerName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? rank : "\(name.uppercased()) · \(rank)"
    }

    // MARK: - Quest variant

    private func questBody(_ quest: Quest, xpTotal: Int) -> some View {
        VStack(spacing: 0) {
            Text("QUEST COMPLETE!")
                .font(.pixel(15))
                .foregroundStyle(BRTheme.gold)
                .padding(.bottom, 16)

            HStack(spacing: 10) {
                ForEach(Array(quest.rewardEmojis.enumerated()), id: \.offset) { index, emoji in
                    if index > 0 {
                        Text("+")
                            .font(.pixel(14))
                            .foregroundStyle(BRTheme.mutedOnDark)
                    }
                    Text(emoji)
                        .font(.system(size: quest.rewardEmojis.count > 1 ? 46 : 58))
                }
            }
            .padding(.bottom, 10)

            Text(quest.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let goal = quest.goalCalories {
                Text("\(goal) CAL GOAL")
                    .font(.caption)
                    .foregroundStyle(BRTheme.mutedOnDark)
                    .padding(.top, 2)
            }

            HStack {
                Text("EXP")
                    .font(.pixel(8))
                    .foregroundStyle(BRTheme.gold)
                Spacer()
                Text("100%")
                    .font(.pixel(10))
                    .foregroundStyle(BRTheme.greenFG)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)
            BRProgressBar(fraction: 1, fill: BRTheme.expFill, height: 9)

            HStack(spacing: 0) {
                shareStat(value: "\(quest.calories)", label: "CAL BURNED", tint: BRTheme.orangeFG)
                statDivider
                shareStat(value: BRFormat.duration(quest.duration), label: "TIME", tint: BRTheme.blueFG)
                statDivider
                shareStat(value: "+\(xpTotal)", label: "XP", tint: BRTheme.gold)
            }
            .padding(.top, 14)

            if let precision = precisionLine(quest) {
                Text(precision)
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.greenFG)
                    .padding(.top, 12)
            }
        }
    }

    /// The rewarded skill gets the flex line — only when the landing was
    /// actually tight (within the precision-bonus window).
    private func precisionLine(_ quest: Quest) -> String? {
        guard quest.earned, let goal = quest.goalCalories, goal > 0,
              quest.calories >= goal else { return nil }
        let over = Double(quest.calories - goal) / Double(goal)
        guard over <= 0.30 else { return nil }  // TODO(final): GameBalance falloff
        let percent = Int((over * 100).rounded())
        return percent == 0
            ? "🎯 PRECISION LANDING · DEAD ON GOAL"
            : "🎯 PRECISION LANDING · \(percent)% OVER GOAL"
    }

    private var statDivider: some View {
        Rectangle()
            .fill(BRTheme.divider)
            .frame(width: 1, height: 30)
    }

    private func shareStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.pixel(12))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(BRTheme.mutedOnDark)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Badge variant

    private func badgeBody(_ badge: Badge) -> some View {
        VStack(spacing: 0) {
            Text("BADGE EARNED!")
                .font(.pixel(15))
                .foregroundStyle(BRTheme.gold)
                .padding(.bottom, 16)

            if let art = UIImage(named: "badge_\(badge.id)") {
                Image(uiImage: art)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 128, height: 128)
            } else {
                ZStack {
                    Circle()
                        .fill(BRTheme.gold.opacity(0.18))
                        .overlay(Circle().strokeBorder(BRTheme.gold, lineWidth: 1.5))
                        .frame(width: 116, height: 116)
                    Text(badge.emoji).font(.system(size: 54))
                }
            }

            Text(badge.name.uppercased())
                .font(.pixel(12))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 14)

            if !badge.flavor.isEmpty {
                Text(badge.flavor)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.mutedOnDark)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }

            if let date = badge.earnedDate {
                Text("EARNED \(date.formatted(date: .abbreviated, time: .omitted).uppercased())")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.blueFG)
                    .padding(.top, 10)
            }
        }
    }
}

/// The share surface: previews the card, exports it via `ImageRenderer`
/// (@3x — 990 px wide, crisp on any feed), and hands the PNG to the system
/// share sheet / Photos. Everything rendered on-device from local data.
struct ShareCardSheet: View {
    let kind: ShareCardKind
    let level: Int
    let rankTitle: String
    let playerName: String
    @Environment(\.dismiss) private var dismiss
    @State private var cardImage: UIImage?
    @State private var justSaved = false
    @State private var showPostSheet = false
    @ObservedObject private var feed = FeedManager.shared

    /// The guild button only exists for players who've opted in. Read at body
    /// time rather than observed: the sheet is built fresh on each present, and
    /// sign-in state can't change while it's open.
    private var canPostToGuild: Bool { SupabaseAPI.shared.isSignedIn }

    /// The post's summary payload — the same numbers already on the card, and
    /// nothing more. Badge and level-up posts carry no health data at all.
    private var guildPayload: (kind: String, payload: SharePayload, detail: String) {
        switch kind {
        case .quest(let quest, let xpTotal):
            let seconds = Int(quest.duration)
            return ("quest",
                    SharePayload(reward: quest.title, emoji: quest.emoji,
                                 calories: quest.calories, seconds: seconds, xp: xpTotal),
                    "\(quest.calories) cal · \(durationText(seconds)) · +\(xpTotal) XP")
        case .badge(let badge):
            return ("badge",
                    SharePayload(badgeID: badge.id, name: badge.name),
                    badge.requirement)
        }
    }

    private func durationText(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        if m >= 60 { return String(format: "%d:%02d:%02d", m / 60, m % 60, s) }
        return String(format: "%d:%02d", m, s)
    }

    private var shareTitle: String {
        switch kind {
        case .quest: "BurnReward — Quest Complete!"
        case .badge: "BurnReward — Badge Earned!"
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundStyle(BRTheme.blueFG)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Spacer(minLength: 0)

            VStack(spacing: 20) {
                Text("SHARE YOUR WIN")
                    .font(.pixel(12))
                    .foregroundStyle(BRTheme.greenFG)
                    .accessibilityAddTraits(.isHeader)
                ShareCardView(kind: kind, level: level, rankTitle: rankTitle, playerName: playerName)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                if let cardImage {
                    ShareLink(
                        item: Image(uiImage: cardImage),
                        preview: SharePreview(shareTitle, image: Image(uiImage: cardImage))
                    ) {
                        Label("SHARE", systemImage: "square.and.arrow.up")
                            .font(.pixel(11))
                            .foregroundStyle(BRTheme.onNeonGreen)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(BRTheme.neonGreen)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share this card")

                    // Posting to the guild is a separate, deliberate act from
                    // sharing the image outward — different audience, different
                    // data (a summary row, not a picture).
                    if canPostToGuild {
                        Button {
                            showPostSheet = true
                        } label: {
                            Label("POST TO GUILD", systemImage: "person.2.fill")
                                .font(.pixel(10))
                                .foregroundStyle(BRTheme.greenFG)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(BRTheme.greenFG, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Post this win to your guild")
                    }

                    Button {
                        save(cardImage)
                    } label: {
                        Text(justSaved ? "Saved to Photos ✓" : "Save Image")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(justSaved ? BRTheme.greenFG : BRTheme.blueFG)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(justSaved ? "Saved to Photos" : "Save image to Photos")
                } else {
                    // Render is effectively instant; this only flashes if it isn't.
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(BRTheme.bg)
        .onAppear(perform: renderCard)
        // A post that fails has to say so. Without this the storage 403 read
        // as "the button does nothing", which cost a full device test.
        .alert("Couldn't post", isPresented: Binding(
            get: { feed.errorMessage != nil },
            set: { if !$0 { feed.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { feed.errorMessage = nil }
        } message: {
            Text(feed.errorMessage ?? "")
        }
        .sheet(isPresented: $showPostSheet) {
            let post = guildPayload
            PostToGuildSheet(
                headline: postHeadline,
                emoji: postEmoji,
                detail: post.detail
            ) { caption, photos in
                let posted = await FeedManager.shared.post(
                    kind: post.kind, payload: post.payload,
                    caption: caption, photos: photos
                )
                if posted { dismiss() }   // close the share sheet behind it too
                return posted
            }
        }
    }

    private var postHeadline: String {
        switch kind {
        case .quest(let quest, _): "EARNED \(quest.title.uppercased())"
        case .badge(let badge):    "UNLOCKED \(badge.name.uppercased())"
        }
    }

    private var postEmoji: String {
        switch kind {
        case .quest(let quest, _): quest.emoji
        case .badge(let badge):    badge.emoji
        }
    }

    /// Exports the card exactly as previewed. `scale: 3` turns the 330 pt
    /// layout into a ~990 px PNG; transparent corners survive the export.
    private func renderCard() {
        guard cardImage == nil else { return }
        let renderer = ImageRenderer(
            content: ShareCardView(kind: kind, level: level,
                                   rankTitle: rankTitle, playerName: playerName)
        )
        renderer.scale = 3
        renderer.isOpaque = false
        cardImage = renderer.uiImage
    }

    private func save(_ image: UIImage) {
        // Add-only Photos access — the system prompts on first save
        // (NSPhotoLibraryAddUsageDescription).
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        justSaved = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            justSaved = false
        }
    }
}

#Preview("Share card — quest") {
    ShareCardSheet(
        kind: .quest(
            Quest(id: UUID(), startDate: .now.addingTimeInterval(-3000), endDate: .now,
                  duration: 2892, calories: 412, averageHeartRate: 128, steps: 4211,
                  activityLabel: "RUN", rewardNames: ["Pizza Slice"], rewardEmojis: ["🍕"],
                  goalCalories: 400, earned: true, isLegacy: false),
            xpTotal: 564
        ),
        level: 6, rankTitle: "SNACK SLAYER", playerName: "Xavier"
    )
}
