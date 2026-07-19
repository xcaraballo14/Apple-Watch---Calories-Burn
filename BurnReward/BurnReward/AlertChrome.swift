import SwiftUI

/// The beveled, cut-corner plate the alerts screen frames every icon in
/// (Xavier's design, 2026-07-19). Drawn rather than shipped as art so it
/// scales, themes, and recolors per alert kind.
/// `InsettableShape` rather than plain `Shape` so `strokeBorder` draws the
/// outline *inside* the plate — a centred `stroke` would bleed half a point
/// past the fill and fray the corners.
struct BevelPlate: InsettableShape {
    var cut: CGFloat = 7
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> BevelPlate {
        BevelPlate(cut: cut, inset: inset + amount)
    }

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let c = min(cut, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        path.closeSubpath()
        return path
    }
}

/// An alert's icon in its plate. The accent comes from the alert kind, so the
/// section reads as colour-coded at a glance: green for your own progress,
/// gold for something waiting on you, orange for reactions, magenta for a new
/// party member.
struct AlertIconTile: View {
    let emoji: String
    let accent: Color
    /// Optional corner stamp — the requester's level, in the mockup.
    var stamp: String?
    var size: CGFloat = 54
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                BevelPlate()
                    .fill(accent.opacity(0.14))
                BevelPlate()
                    .strokeBorder(accent, lineWidth: 1.5)
                Text(emoji).font(.system(size: size * 0.44))
            }
            .frame(width: size, height: size)
            // The glow is what makes the plate read as lit rather than flat.
            // Reduce Motion users still get it (it's static), but it stays
            // subtle enough not to hurt contrast on the label beside it.
            .shadow(color: accent.opacity(reduceMotion ? 0.25 : 0.45), radius: 6)

            if let stamp {
                Text(stamp)
                    .font(.pixel(7))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        BevelPlate(cut: 3)
                            .fill(BRTheme.bg)
                            .overlay(BevelPlate(cut: 3).strokeBorder(accent, lineWidth: 1))
                    )
                    .offset(x: 5, y: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Section header with the bracket flourishes from Xavier's mockup.
struct AlertSectionHeader: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            marks(mirrored: false)
            Text(text)
                .font(.pixel(11))
                .foregroundStyle(BRTheme.textMuted)
            marks(mirrored: true)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }

    /// Drawn pixel ticks rather than a glyph — a rotated character rendered as
    /// faint dots at this size and read as dirt on the screen.
    private func marks(mirrored: Bool) -> some View {
        HStack(spacing: 2) {
            Rectangle().frame(width: 3, height: 3)
            Rectangle().frame(width: 3, height: 9)
        }
        .foregroundStyle(BRTheme.greenFG.opacity(0.75))
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }
}

/// The thin progress bar under a nudge, with its readout on the right.
struct AlertProgressBar: View {
    let progress: AlertProgress

    var body: some View {
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(BRTheme.track)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geo.size.width * progress.fraction, 3))
                }
            }
            .frame(height: 7)
            Text(progress.readout)
                .font(.pixel(8))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: \(progress.readout)")
    }

    private var tint: Color {
        switch progress.tint {
        case .green:  BRTheme.greenFG
        case .gold:   BRTheme.gold
        case .orange: BRTheme.orangeFG
        }
    }
}

/// The encouragement strip that closes the NEXT UP panel. Deliberately warm
/// and never scolding — the streak is stated, never demanded (health rule:
/// all pressure stays weekly, and a streak is a stat, not a threat).
struct AlertStreakFooter: View {
    let name: String
    let streakDays: Int

    var body: some View {
        HStack(spacing: 10) {
            Text("🛡")
                .font(.system(size: 13))
                .accessibilityHidden(true)
            Text(greeting)
                .font(.pixel(8))
                .foregroundStyle(BRTheme.greenFG)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if streakDays > 0 {
                Rectangle()
                    .fill(BRTheme.cardBorder)
                    .frame(width: 1, height: 16)
                Text("🔥")
                    .font(.system(size: 13))
                    .accessibilityHidden(true)
                Text("\(streakDays) DAY STREAK")
                    .font(.pixel(8))
                    .foregroundStyle(BRTheme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            BevelPlate(cut: 6)
                .fill(BRTheme.greenFG.opacity(0.07))
                .overlay(
                    BevelPlate(cut: 6).strokeBorder(BRTheme.greenFG.opacity(0.35), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streakDays > 0
            ? "\(greeting). \(streakDays) day streak."
            : greeting)
    }

    private var greeting: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "KEEP IT UP" : "KEEP IT UP, @\(trimmed.uppercased())"
    }
}
