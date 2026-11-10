import SwiftUI

/// The app's main action: the organic star with a label beside it, on a soft capsule.
///
/// - `.large` – the one primary action of a screen or a step ("zaczynamy", "dalej"): 56 pt tall,
///   full width, a filled champagne capsule.
/// - `.regular` – a secondary action inside a card ("dopisz posiłek"): 44 pt tall, as wide as its
///   label, a quiet capsule with the star in the accent.
///
/// A light haptic on every tap. For a bare icon-sized star (no label) keep `StarButton`.
struct StarActionButton: View {
    enum Size {
        case large
        case regular
    }

    private let title: String
    private let size: Size
    private let isEnabled: Bool
    private let action: () -> Void
    @State private var taps = 0

    init(_ title: String, size: Size = .large, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.size = size
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        let isLarge = size == .large
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: Spacing.item) {
                OrganicStar()
                    .fill(isLarge ? Palette.onAccent : Palette.accent)
                    .frame(width: isLarge ? 18 : 15, height: isLarge ? 18 : 15)
                    .accessibilityHidden(true)
                Text(title)
                    .font(isLarge ? Font.body.weight(.semibold) : Font.subheadline.weight(.medium))
                    .foregroundStyle(isLarge ? Palette.onAccent : Palette.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(.horizontal, isLarge ? Spacing.card : Spacing.cardGap)
            .padding(.vertical, Spacing.tight)
            .frame(maxWidth: isLarge ? CGFloat.infinity : nil, minHeight: isLarge ? TapSize.large : TapSize.minimum)
            .background {
                Capsule()
                    .fill(isLarge ? Palette.accent : Palette.accentBackground)
            }
            .overlay {
                Capsule()
                    .strokeBorder(isLarge ? Color.clear : Palette.accent.opacity(0.3), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(StarActionPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

/// Settles in a little and brightens when pressed.
struct StarActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
