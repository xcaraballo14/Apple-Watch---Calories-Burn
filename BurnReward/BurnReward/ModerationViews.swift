import SwiftUI

// P4a — report + block (mockup draft, 2026-07-19). Actions are stubs until
// Xavier locks the design; the `reports`/`blocks` schema lands with the wiring.

/// The closed reason list. Raw values are what the future `reports.reason`
/// check constraint accepts — copy can change, raw values can't.
enum ReportReason: String, CaseIterable, Identifiable {
    case inappropriate
    case spam
    case harassment
    case other

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .inappropriate: "🚫"
        case .spam:          "🪤"
        case .harassment:    "🗡️"
        case .other:         "❓"
        }
    }

    var label: String {
        switch self {
        case .inappropriate: "NOT APPROPRIATE"
        case .spam:          "SPAM OR A SCAM"
        case .harassment:    "HARASSMENT"
        case .other:         "SOMETHING ELSE"
        }
    }

    var blurb: String {
        switch self {
        case .inappropriate: "Nudity, violence, or hate"
        case .spam:          "Ads, bait, or a fake win"
        case .harassment:    "Targets or bullies someone"
        case .other:         "Tell the guildmaster below"
        }
    }
}

/// One report flow for every target — a post or a player. `subject` is what
/// the header names ("@eli787's post", "@eli787").
struct ReportSheet: View {
    let subject: String
    /// Returns nil on success (the sheet dismisses) or the error text to
    /// show (the sheet stays open) — a failed report must never look sent.
    let onSubmit: (ReportReason, String) async -> String?

    @State private var reason: ReportReason?
    @State private var note = ""
    @State private var isSending = false
    @State private var sendError: String?
    @FocusState private var noteFocused: Bool
    @Environment(\.dismiss) private var dismiss

    /// Same cap the caption gets — enforced again server-side when wired.
    private let noteLimit = 200

    var body: some View {
        NavigationStack {
            ZStack {
                BRTheme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        reasonList
                        noteField
                        submitButton
                        Text("Reports go straight to the guildmaster and are reviewed within 24 hours. What you report disappears from your feed as soon as you send.")
                            .font(.footnote)
                            .foregroundStyle(BRTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BRTheme.textMuted)
                        .disabled(isSending)
                }
            }
            .alert("Report", isPresented: Binding(
                get: { sendError != nil },
                set: { if !$0 { sendError = nil } }
            )) {
                Button("OK", role: .cancel) { sendError = nil }
            } message: {
                Text(sendError ?? "")
            }
        }
        .presentationDetents([.height(620), .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSending)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REPORT")
                .font(.pixel(16))
                .foregroundStyle(BRTheme.alertRed)
            Text(subject)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BRTheme.textPrimary)
        }
    }

    private var reasonList: some View {
        VStack(alignment: .leading, spacing: 8) {
            PixelSectionLabel(text: "WHY ARE YOU REPORTING THIS?")
            ForEach(ReportReason.allCases) { option in
                reasonRow(option)
            }
        }
    }

    private func reasonRow(_ option: ReportReason) -> some View {
        let selected = reason == option
        return Button {
            reason = option
        } label: {
            HStack(spacing: 10) {
                Text(option.emoji).font(.system(size: 16))
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.pixel(9))
                        .foregroundStyle(selected ? BRTheme.alertRed : BRTheme.textPrimary)
                    Text(option.blurb)
                        .font(.footnote)
                        .foregroundStyle(BRTheme.textMuted)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? BRTheme.alertRed : BRTheme.cardBorder)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? BRTheme.alertRed.opacity(0.10) : BRTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? BRTheme.alertRed : BRTheme.cardBorder,
                                          lineWidth: selected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label). \(option.blurb).")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PixelSectionLabel(text: "ANYTHING ELSE? (OPTIONAL)")
                Spacer()
                Text("\(note.count)/\(noteLimit)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BRTheme.textMuted)
            }
            TextField("What should the guildmaster know?", text: $note, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(BRTheme.textPrimary)
                .lineLimit(3...5)
                .focused($noteFocused)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BRTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(BRTheme.cardBorder, lineWidth: 1)
                        )
                )
                .onChange(of: note) { _, value in
                    if value.count > noteLimit { note = String(value.prefix(noteLimit)) }
                }
        }
    }

    private var submitButton: some View {
        Button {
            guard let reason, !isSending else { return }
            noteFocused = false
            isSending = true
            Task {
                let failure = await onSubmit(reason, note)
                isSending = false
                if let failure {
                    sendError = failure    // stays open — a failed report must be visible
                } else {
                    dismiss()
                }
            }
        } label: {
            ZStack {
                Text("SEND REPORT")
                    .font(.pixel(10))
                    .foregroundStyle(.white)
                    .opacity(isSending ? 0 : 1)
                if isSending {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(reason == nil ? BRTheme.alertRed.opacity(0.35) : BRTheme.alertRed)
            )
        }
        .buttonStyle(.plain)
        .disabled(reason == nil || isSending)
        .accessibilityHint(reason == nil ? "Pick a reason first." : "Sends the report.")
    }
}

// MARK: - Blocked players (Settings)

/// The unblock surface — Xavier's ruling: out of the way in Settings, not on
/// the party screen. Fetches fresh on appear; blocking elsewhere doesn't need
/// to keep this in sync.
struct BlockedPlayersView: View {
    @State private var players: [SocialProfile] = []
    @State private var isLoading = true
    @State private var working: UUID?
    @State private var errorText: String?

    var body: some View {
        ZStack {
            BRTheme.bg.ignoresSafeArea()
            if isLoading {
                ProgressView()
            } else if players.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(BRTheme.textMuted)
                    Text("NOBODY BLOCKED")
                        .font(.pixel(11))
                        .foregroundStyle(BRTheme.textPrimary)
                    Text("Players you block land here, and only you can let them back.")
                        .font(.footnote)
                        .foregroundStyle(BRTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(players) { player in
                            row(player)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Blocked players")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Guild", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button("OK", role: .cancel) { errorText = nil }
        } message: {
            Text(errorText ?? "")
        }
    }

    private func row(_ player: SocialProfile) -> some View {
        HStack(spacing: 12) {
            GuildAvatar(profile: player, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("@\(player.username)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BRTheme.textPrimary)
                Text("LVL \(player.level) · \(player.title)")
                    .font(.pixel(7))
                    .foregroundStyle(BRTheme.textMuted)
            }
            Spacer(minLength: 8)
            Button {
                working = player.id
                Task {
                    if let failure = await ModerationClient.shared.unblock(userID: player.id) {
                        errorText = failure
                    } else {
                        players.removeAll { $0.id == player.id }
                    }
                    working = nil
                }
            } label: {
                if working == player.id {
                    ProgressView()
                        .frame(minWidth: 74, minHeight: 34)
                } else {
                    Text("UNBLOCK")
                        .font(.pixel(7))
                        .foregroundStyle(BRTheme.greenFG)
                        .frame(minWidth: 74, minHeight: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(BRTheme.greenFG.opacity(0.5), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(working != nil)
            .accessibilityLabel("Unblock \(player.username)")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BRTheme.card))
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            players = try await ModerationClient.shared.blockedPlayers()
        } catch {
            if !error.isCancellation {
                errorText = "Couldn't load the list — pull back in and try again."
            }
        }
        isLoading = false
    }
}

#Preview("Report — post") {
    ReportSheet(subject: "@eli787's post — UNLOCKED FIRST BURN") { _, _ in nil }
}

#Preview("Report — player") {
    ReportSheet(subject: "@eli787") { _, _ in nil }
}

#Preview("Blocked players") {
    NavigationStack { BlockedPlayersView() }
}
