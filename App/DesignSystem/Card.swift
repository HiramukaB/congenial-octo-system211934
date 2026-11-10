import SwiftUI

/// Frosted dark card on top of the moving background.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Palette.card.opacity(0.55))
                }
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.07), lineWidth: 1)
            }
    }
}

/// A scrolling tab with the usual margins and the ambient background.
struct Screen<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
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
struct StatusBarFade: View {
    var body: some View {
        GeometryReader { proxy in
            LinearGradient(stops: [
                Gradient.Stop(color: Palette.background.opacity(0.88), location: 0),
                Gradient.Stop(color: Palette.background.opacity(0.7), location: 0.6),
                Gradient.Stop(color: Palette.background.opacity(0), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .frame(height: proxy.safeAreaInsets.top + 10)
        }
        // Reaching up into the status bar is what makes `safeAreaInsets.top` its height.
        .ignoresSafeArea(edges: .top)
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
