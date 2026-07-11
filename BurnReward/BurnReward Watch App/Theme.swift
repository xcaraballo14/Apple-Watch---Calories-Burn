import SwiftUI

/// Exact palette + pixel font from the BurnReward landing page (dark theme).
enum Theme {
    static let green  = Color(red: 0.00, green: 1.00, blue: 0.53) // #00ff88
    static let yellow = Color(red: 1.00, green: 0.84, blue: 0.00) // #ffd700
    static let orange = Color(red: 1.00, green: 0.42, blue: 0.21) // #ff6b35
    static let red    = Color(red: 1.00, green: 0.13, blue: 0.27) // #ff2244
    static let blue   = Color(red: 0.00, green: 0.67, blue: 1.00) // #00aaff
    static let muted  = Color(red: 0.38, green: 0.38, blue: 0.63) // #6060a0
    static let bg     = Color(red: 0.012, green: 0.039, blue: 0.016) // #030a04
    static let card   = Color(white: 0.06)
}

extension Font {
    /// Press Start 2P at the given point size. Falls back to monospaced if the
    /// font failed to load for any reason.
    static func pixel(_ size: CGFloat) -> Font {
        .custom("PressStart2P-Regular", size: size)
    }
}

/// Watch-side time formatting. Mirrors the iOS `BRFormat.duration` behavior so a
/// quest that runs past an hour reads "1:15:00", not "75:00".
enum WatchFormat {
    /// 1725 s → "28:45"; adds an hours field once the quest passes 60 minutes.
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

/// Retro CRT scanline overlay to match the site's aesthetic.
struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let lineGap: CGFloat = 3
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    ctx.fill(Path(rect), with: .color(.black.opacity(0.18)))
                    y += lineGap
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
