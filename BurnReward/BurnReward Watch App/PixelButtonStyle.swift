import SwiftUI

struct PixelButtonStyle: ButtonStyle {
    var enabled: Bool = true
    private let shadowHeight: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(.system(.footnote, design: .monospaced).weight(.bold))
            .foregroundStyle(enabled ? .black : Color(white: 0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                enabled
                    ? Color(red: 0, green: 1, blue: 0.53)   // #00ff88
                    : Color(white: 0.1)                      // #1a1a1a
            )
            .padding(.bottom, pressed || !enabled ? 0 : shadowHeight)
            .background(
                enabled
                    ? Color(red: 0, green: 0.47, blue: 0.27) // #007744 shadow
                    : Color.clear
            )
            .animation(.easeInOut(duration: 0.08), value: pressed)
    }
}
