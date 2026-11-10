import SwiftUI

/// What a place says while it is still empty: a few soft stars, one warm line, maybe a short hint,
/// and the action that fills it. Inviting, never a warning.
///
///     EmptyState(title: "tu zbierzesz to, co Cię bawi",
///                message: "żarty i cytaty, do których zechcesz wracać",
///                actionTitle: "dodaj pierwszy") { startNew() }
struct EmptyState: View {
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.item) {
            StarCluster()
            Text(polish: title)
                .displayFont(19, italic: true, relativeTo: .title3)
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(polish: message)
                    .hintText()
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                StarActionButton(actionTitle, size: .regular, action: action)
                    .padding(.top, Spacing.hairline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.group)
    }
}

/// Three soft stars, the app's quiet picture for "nothing here yet".
struct StarCluster: View {
    var body: some View {
        ZStack {
            OrganicStar()
                .fill(Palette.accent.opacity(0.9))
                .frame(width: 28, height: 28)
            OrganicStar()
                .fill(Palette.accentDim.opacity(0.7))
                .frame(width: 12, height: 12)
                .offset(x: 24, y: -14)
            OrganicStar()
                .fill(Palette.accentDim.opacity(0.5))
                .frame(width: 9, height: 9)
                .offset(x: -22, y: 12)
        }
        .frame(width: 80, height: 48)
        .accessibilityHidden(true)
    }
}

/// Details on tap: a short link ("jak to liczę?") that opens a longer hint in place and closes it
/// again. Long explanations live here instead of on the card.
struct MoreInfo: View {
    private let label: String
    private let text: String
    @State private var isOpen = false

    init(_ label: String = "więcej", text: String) {
        self.label = label
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    isOpen.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(label)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
            .accessibilityValue(Text(isOpen ? "rozwinięte" : "zwinięte"))
            if isOpen {
                Text(polish: text)
                    .hintText()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A short, warm confirmation in place – "zapisałam", "dziękuję, że znalazłaś chwilę" – with a
/// small star. It fades in where she is looking; nothing pops up or blocks the screen.
struct ConfirmationNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
            OrganicStar()
                .fill(Palette.accent)
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            Text(polish: text)
                .font(.footnote)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity)
    }
}
