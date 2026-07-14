import SwiftUI

struct PixelButtonStyle: ButtonStyle {
    var enabled: Bool = true
    var fill: Color = Theme.green
    var shadow: Color = Color(red: 0, green: 0.47, blue: 0.27) // #007744
    private let shadowHeight: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(.pixel(9))
            .foregroundStyle(enabled ? .black : Color(white: 0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(enabled ? fill : Color(white: 0.1))
            .padding(.bottom, pressed || !enabled ? 0 : shadowHeight)
            .background(enabled ? shadow : Color.clear)
            .animation(.easeInOut(duration: 0.08), value: pressed)
    }
}
