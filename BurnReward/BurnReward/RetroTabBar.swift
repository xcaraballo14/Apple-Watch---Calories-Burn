import SwiftUI
import UIKit

/// The console-style bottom bar that replaces the system tab bar (Xavier:
/// "extend completely, not feel like an iPhone navigation bar"). Full-width,
/// bleeds through the home-indicator area, dark island surface in both themes,
/// gold hairline on top, and Xavier's pixel icons tinted per state.
struct RetroTabBar: View {
    @Binding var selected: AppTab

    private let items: [(tab: AppTab, icon: String, label: String)] = [
        (.home, "tab_home", "HOME"),
        (.history, "tab_log", "LOG"),
        (.rewards, "tab_forge", "FORGE"),
        (.character, "tab_character", "CHARACTER"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                barItem(item.tab, icon: item.icon, label: item.label)
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

    private func barItem(_ tab: AppTab, icon: String, label: String) -> some View {
        let isSelected = selected == tab
        return Button {
            selected = tab
        } label: {
            VStack(spacing: 4) {
                // 2pt "cartridge slot" indicator above the active icon.
                Rectangle()
                    .fill(isSelected ? BRTheme.neonGreen : Color.clear)
                    .frame(width: 22, height: 2)
                iconImage(icon)
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
    /// crisp); falls back to an SF Symbol if the asset is ever missing.
    @ViewBuilder
    private func iconImage(_ name: String) -> some View {
        if let ui = UIImage(named: name) {
            Image(uiImage: ui)
                .renderingMode(.template)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            Image(systemName: "square.dashed")
                .font(.system(size: 20))
        }
    }
}
