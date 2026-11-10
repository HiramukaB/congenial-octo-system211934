import SwiftUI

/// How a card stands out from the background (DESIGN.md, "Cards").
enum CardStyle {
    /// Frosted dark card – almost everything.
    case standard
    /// A touch of the accent: the one card a screen is about (today's cycle day, a welcome step).
    case highlight
    /// No fill, only a hairline: secondary content that shouldn't compete with the cards around it.
    case quiet
}

/// A card on top of the moving background: 20 pt inside, 24 pt corners.
struct Card<Content: View>: View {
    var padding: CGFloat = Spacing.card
    var style: CardStyle = .standard
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                surface(shape)
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: 1)
            }
    }

    @ViewBuilder
    private func surface(_ shape: RoundedRectangle) -> some View {
        switch style {
        case .standard:
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Palette.card.opacity(0.55))
            }
        case .highlight:
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(Palette.card.opacity(0.5))
                shape.fill(LinearGradient(colors: [Palette.accent.opacity(0.12), Palette.accent.opacity(0.03)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        case .quiet:
            shape.fill(Color.white.opacity(0.025))
        }
    }

    private var borderColor: Color {
        switch style {
        case .standard: Color.white.opacity(0.07)
        case .highlight: Palette.accent.opacity(0.22)
        case .quiet: Color.white.opacity(0.08)
        }
    }
}

/// A scrolling screen with the usual margins and the ambient background: 20 pt at the sides,
/// 16 pt between cards. The tab bar always stays visible; the scroll view's safe area ends above
/// it, so the last card scrolls clear of it, with 32 pt to spare.
struct Screen<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                content
            }
            .padding(.horizontal, Spacing.card)
            .padding(.top, Spacing.tight)
            .padding(.bottom, Spacing.section)
        }
        .scrollIndicators(.hidden)
        // Dragging down into the keyboard closes it, which also saves what she typed.
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .top) {
            StatusBarFade()
        }
        .ambientBackground(tint: tint)
    }
}

/// A soft fade of the night colour under the status bar, so text scrolled up doesn't run into
/// the clock. It covers only the status bar and a few points below it, and takes no touches.
///
/// It sits at the top of the safe area. The colour behind its zero-height top reaches up
/// through the status bar – a background extends into the safe area it touches – so it fits
/// any status bar height without measuring it. (A GeometryReader that ignores the safe area
/// reads its top inset as 0, which left only a sliver.)
struct StatusBarFade: View {
    private static let opacity = 0.9

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(Palette.background.opacity(Self.opacity), ignoresSafeAreaEdges: .top)
            LinearGradient(colors: [Palette.background.opacity(Self.opacity), Palette.background.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 14)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Text action styled like the underlined links of the web version.
struct LinkButtonStyle: ButtonStyle {
    var font: Font = .subheadline.weight(.medium)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(Palette.accent)
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Palette.accent.opacity(0.3))
                    .frame(height: 1)
            }
            .opacity(configuration.isPressed ? 0.55 : 1)
            // A tap area of at least 44 pt without changing the layout around the link.
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .padding(.vertical, -10)
    }
}

extension View {
    /// The look of a field while she types in it: a soft warm box with a hairline of the accent.
    /// Every open text field in the app wears it, so writing looks the same everywhere.
    func fieldBox() -> some View {
        padding(Spacing.item + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .fill(Palette.accentBackground.opacity(0.6))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1)
            }
    }
}
