import SwiftUI

/// The home for alerts behind the header bell. v1 = an in-app feed: a "next up"
/// nudge section on top, then a history of achievement events. Everything is
/// derived from quest history (see `AlertFeed`) — no backend, no push.
struct NotificationsView: View {
    @ObservedObject var model: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.alertNudges.isEmpty && model.alertRecent.isEmpty {
                    emptyState
                } else {
                    List {
                        if !model.alertNudges.isEmpty {
                            Section {
                                ForEach(model.alertNudges) { row($0) }
                            } header: { sectionHeader("NEXT UP") }
                        }
                        if !model.alertRecent.isEmpty {
                            Section {
                                ForEach(model.alertRecent) { row($0) }
                            } header: { sectionHeader("RECENT") }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 8, for: .scrollContent)
                }
            }
            .background(BRTheme.bg)
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

    // MARK: - Rows

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.pixel(11))
            .foregroundStyle(BRTheme.textMuted)
    }

    private func row(_ item: AlertItem) -> some View {
        let isNew = model.isUnread(item)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint(item.kind))
                    .frame(width: 40, height: 40)
                    .overlay(
                        item.kind == .badge
                            ? Circle().strokeBorder(BRTheme.gold, lineWidth: 1)
                            : nil
                    )
                Text(item.emoji).font(.system(size: 20))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BRTheme.textPrimary)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(BRTheme.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                Text(item.time)
                    .font(.caption2)
                    .foregroundStyle(BRTheme.textMuted)
                if isNew {
                    Circle()
                        .fill(BRTheme.neonGreen)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(BRTheme.card)
        .listRowSeparatorTint(BRTheme.divider)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isNew ? "New. " : "")\(item.title). \(item.detail). \(item.time).")
    }

    private func tint(_ kind: AlertItem.Kind) -> Color {
        switch kind {
        case .nudge:   BRTheme.tintYellow
        case .streak:  BRTheme.tintBlue
        case .badge:   BRTheme.gold.opacity(0.15)
        case .levelUp: BRTheme.tintGreen
        case .record:  BRTheme.tintOrange
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
            Text("Finish a quest on your Apple Watch and your level-ups, badges, and streak nudges show up here.")
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
