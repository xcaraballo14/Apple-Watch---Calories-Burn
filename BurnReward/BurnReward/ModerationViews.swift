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
    /// Stub in the mockup; the lock wires it to the `reports` insert.
    let onSubmit: (ReportReason, String) -> Void

    @State private var reason: ReportReason?
    @State private var note = ""
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
                }
            }
        }
        .presentationDetents([.height(620), .large])
        .presentationDragIndicator(.visible)
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
            guard let reason else { return }
            onSubmit(reason, note)
            dismiss()
        } label: {
            Text("SEND REPORT")
                .font(.pixel(10))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(reason == nil ? BRTheme.alertRed.opacity(0.35) : BRTheme.alertRed)
                )
        }
        .buttonStyle(.plain)
        .disabled(reason == nil)
        .accessibilityHint(reason == nil ? "Pick a reason first." : "Sends the report.")
    }
}

#Preview("Report — post") {
    ReportSheet(subject: "@eli787's post — UNLOCKED FIRST BURN") { _, _ in }
}

#Preview("Report — player") {
    ReportSheet(subject: "@eli787") { _, _ in }
}
