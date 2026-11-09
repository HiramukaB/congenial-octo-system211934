import SwiftUI

/// The soft four-pointed star from the web version – used instead of rectangular buttons.
/// `nonisolated`, because SwiftUI may compute shape paths off the main thread.
nonisolated struct OrganicStar: Shape {
    func path(in rect: CGRect) -> Path {
        // Same curves as the original 24×24 SVG path, scaled into `rect`.
        let scale = min(rect.width, rect.height) / 24
        let originX = rect.midX - 12 * scale
        let originY = rect.midY - 12 * scale
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: originX + x * scale, y: originY + y * scale)
        }

        var path = Path()
        path.move(to: point(12, 2))
        path.addCurve(to: point(15.4, 10.1), control1: point(12.9, 7.2), control2: point(13.4, 8.6))
        path.addCurve(to: point(22, 12), control1: point(17.1, 11.4), control2: point(19, 11.6))
        path.addCurve(to: point(15.4, 13.9), control1: point(19, 12.4), control2: point(17.1, 12.6))
        path.addCurve(to: point(12, 22), control1: point(13.4, 15.4), control2: point(12.9, 16.8))
        path.addCurve(to: point(8.6, 13.9), control1: point(11.1, 16.8), control2: point(10.6, 15.4))
        path.addCurve(to: point(2, 12), control1: point(6.9, 12.6), control2: point(5, 12.4))
        path.addCurve(to: point(8.6, 10.1), control1: point(5, 11.6), control2: point(6.9, 11.4))
        path.addCurve(to: point(12, 2), control1: point(10.6, 8.6), control2: point(11.1, 7.2))
        path.closeSubpath()
        return path
    }
}

/// A star-shaped button: grows and turns a little when pressed, with a light tap of haptics.
struct StarButton: View {
    let label: String
    var size: CGFloat = 17
    var prominent = false
    var isEnabled = true
    @State var taps = 0
    let action: () -> Void

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            OrganicStar()
                .fill(prominent ? Palette.accent : Palette.accentDim)
                .frame(width: size, height: size)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(StarPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.22)
        .accessibilityLabel(Text(label))
        .sensoryFeedback(.selection, trigger: taps)
    }
}

struct StarPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.18 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? 12 : 0))
            .brightness(configuration.isPressed ? 0.15 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
