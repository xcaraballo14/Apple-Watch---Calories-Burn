import SwiftUI
import UIKit

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    /// Resolves to a different color in light vs dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    init(both hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

/// iPhone palette. Same arcade identity as the watch's `Theme`, adapted for
/// light + dark: neon colors survive as *fills* (with a dark same-family color
/// on top), while anything used as text darkens to a contrast-safe counterpart
/// in light mode.
enum BRTheme {
    // Surfaces — light mode is a warm "retro console cream" rather than a cool
    // gray-white, so the neon fills and gold accents have something to pop off.
    static let bg          = Color(light: 0xF3F0E5, dark: 0x0E0E14)
    static let card        = Color(light: 0xFFFEF9, dark: 0x171722)
    static let cardBorder  = Color(light: 0xE6E1D0, dark: 0x171722)
    static let track       = Color(light: 0xE9E4D4, dark: 0x262635)
    static let divider     = Color(light: 0xEFEBDD, dark: 0x22222E)
    static let weekEmpty   = Color(light: 0xEFEBDC, dark: 0x22222E)
    static let weekBorder  = Color(light: 0xDFD8C4, dark: 0x2E2E3C)
    /// Small always-dark accent tiles (LV badge, avatar) that keep the arcade
    /// identity visible even in light mode.
    static let darkIsland  = Color(light: 0x14141C, dark: 0x0E0E14)

    // Tinted fills for the stat tiles (light mode only — dark keeps flat cards)
    static let tintGreen   = Color(light: 0xDFF2E2, dark: 0x171722)
    static let tintBlue    = Color(light: 0xE0EEF8, dark: 0x171722)
    static let tintOrange  = Color(light: 0xFBEADC, dark: 0x171722)
    static let tintYellow  = Color(light: 0xF7EDCE, dark: 0x171722)

    // Text
    static let textPrimary = Color(light: 0x24211A, dark: 0xF2F4F8)
    static let textMuted   = Color(light: 0x635F51, dark: 0x8B93A7)
    static let mutedOnDark = Color(both: 0x8B93A7)   // muted text on darkIsland tiles

    // Foreground accents (contrast-safe in both modes)
    static let greenFG  = Color(light: 0x007A43, dark: 0x00FF88)
    static let blueFG   = Color(light: 0x006DAE, dark: 0x00AAFF)
    static let orangeFG = Color(light: 0xC2410C, dark: 0xFF6B35)
    static let yellowFG = Color(light: 0x7A6200, dark: 0xFFD700)

    // Neon fills (identical in both modes; pair with the "on" colors)
    static let neonGreen   = Color(both: 0x00FF88)
    static let onNeonGreen = Color(both: 0x04351C)
    static let expFill     = Color(both: 0xFFD700)
    static let xpFill      = Color(both: 0x00AAFF)
    /// Weekly-challenge progress — orange so it can't be confused with the
    /// gold quest EXP bar or the blue level XP bar.
    static let challengeFill = Color(both: 0xFF6B35)
    static let gold        = Color(light: 0xD9A800, dark: 0xFFD700)
    static let alertRed    = Color(both: 0xFF2244)
}

extension Font {
    /// Press Start 2P, scaled with Dynamic Type relative to a text style so
    /// pixel labels grow alongside the user's accessibility settings.
    static func pixel(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom("PressStart2P-Regular", size: size, relativeTo: style)
    }
}

/// Standard card chrome: 14pt corners, hairline border in light mode.
/// Pass a `fill` to make a tinted card (stat tiles); tinted cards drop the
/// border so the tint reads as the surface itself.
struct BRCard: ViewModifier {
    var padding: CGFloat = 14
    var fill: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fill ?? BRTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(fill == nil ? BRTheme.cardBorder : .clear, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func brCard(padding: CGFloat = 14, fill: Color? = nil) -> some View {
        modifier(BRCard(padding: padding, fill: fill))
    }
}

/// Small all-caps pixel label used for section headers inside cards.
struct PixelSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.pixel(11))
            .foregroundStyle(BRTheme.textMuted)
    }
}

/// Compact retro header every tab root uses instead of a system nav bar —
/// the same pattern as Home's custom header, so no tab burns vertical space
/// on empty chrome. Pushed detail views keep their normal navigation bars.
struct BRTabHeader<Trailing: View>: View {
    let title: String
    private let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.pixel(12))
                .foregroundStyle(BRTheme.greenFG)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// (The UIKit tab-bar appearance styling that briefly lived here was replaced
// by the fully custom `RetroTabBar` — the system tab bar is hidden entirely.)

enum BRFormat {
    /// 9412 → "9.4K", 940 → "940"
    static func compact(_ value: Int) -> String {
        guard value >= 10_000 else { return value.formatted() }
        let thousands = Double(value) / 1000
        return "\(thousands.formatted(.number.precision(.fractionLength(0...1))))K"
    }

    /// 1721 s → "28:41"; adds hours past 60 minutes.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// "Today", "Mon", or "Jun 26" depending on how recent the date is.
    static func recentDay(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "Today" }
        if let weekAgo = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)),
           date >= weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
