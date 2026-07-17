import SwiftUI
import UIKit

/// The console-style bottom bar that replaces the system tab bar (Xavier:
/// "extend completely, not feel like an iPhone navigation bar"). Full-width,
/// bleeds through the home-indicator area, dark island surface in both themes,
/// gold hairline on top, and Xavier's pixel icons tinted per state.
struct RetroTabBar: View {
    @Binding var selected: AppTab

    /// The bar's laid-out height above the home-indicator area: 8 top padding
    /// + 48 item minHeight + 2 bottom padding. `RootView` reserves exactly
    /// this much window safe area so all content ends above the bar.
    static let height: CGFloat = 58

    // GUILD's pixel icon is pending from Xavier (Art/tab_guild.png loads by
    // convention the moment it exists); the SF fallback carries until then.
    private let items: [(tab: AppTab, icon: String, fallback: String, label: String)] = [
        (.home, "tab_home", "house.fill", "HOME"),
        (.history, "tab_log", "book.closed.fill", "LOG"),
        (.rewards, "tab_forge", "hammer.fill", "FORGE"),
        (.guild, "tab_guild", "person.2.fill", "GUILD"),
        (.character, "tab_character", "person.fill", "CHARACTER"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                barItem(item.tab, icon: item.icon, fallback: item.fallback, label: item.label)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(
            BRTheme.darkIsland
                .overlay(alignment: .top) {
                    Rectangle().fill(BRTheme.gold).frame(height: 1.5)
                }
                .ignoresSafeArea(edges: .bottom)   // extend through the home indicator
        )
    }

    private func barItem(_ tab: AppTab, icon: String, fallback: String, label: String) -> some View {
        let isSelected = selected == tab
        return Button {
            selected = tab
        } label: {
            VStack(spacing: 4) {
                // 2pt "cartridge slot" indicator above the active icon.
                Rectangle()
                    .fill(isSelected ? BRTheme.neonGreen : Color.clear)
                    .frame(width: 22, height: 2)
                iconImage(icon, fallback: fallback)
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(.pixel(6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? BRTheme.neonGreen : BRTheme.mutedOnDark)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.capitalized)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Xavier's pixel icon (template-tinted, nearest-neighbor so it stays
    /// crisp); falls back to a per-item SF Symbol while the art is pending.
    @ViewBuilder
    private func iconImage(_ name: String, fallback: String) -> some View {
        if let ui = UIImage(named: name) {
            Image(uiImage: ui)
                .renderingMode(.template)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: fallback)
                .font(.system(size: 19))
        }
    }
}
