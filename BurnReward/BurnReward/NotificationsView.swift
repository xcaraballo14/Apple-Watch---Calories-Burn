import SwiftUI

/// The home for alerts behind the header bell: a "next up" panel of
/// forward-looking nudges, guild news, then your achievement history.
///
/// NEXT UP and RECENT are derived from quest history (`AlertFeed`) — no
/// backend. The GUILD section is *fetched* (`SocialAlertStore`) and is the one
/// part a reinstall can't rebuild offline; see that file for why they're kept
/// apart.
struct NotificationsView: View {
    @ObservedObject var model: DashboardViewModel
    @ObservedObject private var social = SocialAlertStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("br.displayName") private var displayName = ""
    /// Tapping a guild row should land on the GUILD tab; the sheet's owner
    /// passes this in so the row knows where to go.
    var onOpenGuild: (() -> Void)?

    private var isEmpty: Bool {
        model.alertNudges.isEmpty && model.alertRecent.isEmpty && social.items.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            if !model.alertNudges.isEmpty {
                                section("NEXT UP") {
                                    rows(model.alertNudges)
                                    AlertStreakFooter(name: displayName,
                                                      streakDays: model.stats.streakDays)
                                        .padding(.top, 8)
                                }
                            }
                            // Guild news sits between the forward-looking
                            // nudges and your own history: it's about other
                            // people, and some of it wants an answer.
                            if !social.items.isEmpty {
                                section("GUILD") {
                                    rows(social.items, tappable: true)
                                }
                            }
                            if !model.alertRecent.isEmpty {
                                section("RECENT") {
                                    rows(model.alertRecent)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(BRTheme.bg)
            // Without this the bar reserves room for a large title that never
            // renders (the title is a .principal item), leaving a dead band
            // under the header. Every other sheet in the app already sets it.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ALERTS")
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
        // Mark seen on close (not open) so the "new" dots are still visible
        // while you're reading the feed.
        .onDisappear { model.markAlertsSeen() }
    }

    // MARK: - Structure

    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AlertSectionHeader(text: title)
            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BRTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(BRTheme.greenFG.opacity(0.22), lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private func rows(_ items: [AlertItem], tappable: Bool = false) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if tappable {
                Button {
                    dismiss()
                    onOpenGuild?()
                } label: { row(item) }
                .buttonStyle(.plain)
            } else {
                row(item)
            }
            if index < items.count - 1 {
                Rectangle()
                    .fill(BRTheme.divider)
                    .frame(height: 1)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: - One row

    private func row(_ item: AlertItem) -> some View {
        let isNew = model.isUnread(item)
        return HStack(alignment: .top, spacing: 12) {
            AlertIconTile(emoji: item.emoji, accent: accent(item.kind), stamp: stamp(item))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BRTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text(item.time)
                        .font(.caption2)
                        .foregroundStyle(BRTheme.textMuted)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BRTheme.textMuted)
                        .opacity(item.kind.isSocial ? 1 : 0.35)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.detail)
                        .font(.footnote)
                        .foregroundStyle(BRTheme.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if isNew {
                        Circle()
                            .fill(BRTheme.neonGreen)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                }

                if let progress = item.progress {
                    AlertProgressBar(progress: progress)
                        .padding(.top, 3)
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(item, isNew: isNew))
        .accessibilityHint(item.kind.isSocial ? "Opens the guild." : "")
    }

    private func spoken(_ item: AlertItem, isNew: Bool) -> String {
        var parts = [isNew ? "New." : "", item.title + ".", item.detail + ".", item.time + "."]
        if let progress = item.progress { parts.append("Progress: \(progress.readout).") }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The requester's level rides the plate, so you can size someone up
    /// before opening their profile.
    private func stamp(_ item: AlertItem) -> String? {
        guard item.kind == .friendRequest,
              let range = item.detail.range(of: #"LVL (\d+)"#, options: .regularExpression)
        else { return nil }
        return String(item.detail[range]).replacingOccurrences(of: "LVL ", with: "")
    }

    private func accent(_ kind: AlertItem.Kind) -> Color {
        switch kind {
        case .nudge:         BRTheme.greenFG
        case .streak:        BRTheme.blueFG
        case .badge:         BRTheme.gold
        case .levelUp:       BRTheme.greenFG
        case .record:        BRTheme.orangeFG
        case .friendRequest: BRTheme.gold        // waiting on you
        // Xavier's mockup uses magenta here; the design system has no magenta
        // token, so blue keeps "joined" distinct from gold requests and orange
        // reactions without inventing a one-off colour.
        case .friendJoined:  BRTheme.blueFG
        case .reaction:      BRTheme.orangeFG
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.system(size: 34))
                .foregroundStyle(BRTheme.textMuted)
                .accessibilityHidden(true)
            Text("NO ALERTS YET")
                .font(.pixel(12))
                .foregroundStyle(BRTheme.textPrimary)
            Text("Finish a quest on your Apple Watch and your level-ups, badges, and streak nudges show up here. Guild news lands here too.")
                .font(.footnote)
                .foregroundStyle(BRTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BRTheme.bg)
    }
}

#Preview("Alerts") {
    NotificationsView(model: DashboardViewModel(sample: true))
}
