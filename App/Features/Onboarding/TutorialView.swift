import SwiftUI
import AboutHerCore

/// The short guide to the app: five cards, each with a small live example to try – things save
/// themselves, swipe left to delete, drag a scale, the star is an action, the five tabs. Nothing
/// she does here touches her data.
///
/// She moves on with "dalej" or by swiping the card's text sideways (the examples keep their own
/// swipes and drags), and back the same way. SettingsView opens it as a full-screen cover from the
/// row "samouczek"; the welcome shows it as one of its steps.
///
/// When she is done (or skips it) the guide counts as seen (`store.setTutorialSeen()`) and calls
/// `onFinish`; without `onFinish` it closes itself (`dismiss`). Inside the welcome always pass
/// `onFinish` – a `dismiss` there would close the welcome itself – and `onBack` for the way back
/// from the first card.
struct TutorialView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Called when she is done; nil when the guide should close itself.
    let onFinish: (() -> Void)?
    /// Inside the welcome: back from the first card to the step before it.
    let onBack: (() -> Void)?

    @State private var page = TutorialPage.saving
    @State private var isMovingForward = true

    init(onFinish: (() -> Void)? = nil, onBack: (() -> Void)? = nil) {
        self.onFinish = onFinish
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            WelcomeBar(onBack: backAction,
                       trailingTitle: page.isLast ? nil : (onFinish == nil ? "zamknij" : "pomiń"),
                       onTrailing: finish) {
                TutorialDots(page: page)
            }
            ZStack {
                TutorialCard(page: page, onSwipe: turn(by:))
                    .id(page)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            StarActionButton(buttonTitle, action: advance)
                .padding(.horizontal, Spacing.card)
                .padding(.top, Spacing.item)
                .padding(.bottom, Spacing.tight)
        }
        .background {
            // Inside the welcome its own background is already there.
            if onFinish == nil {
                AmbientBackground(tint: nil)
            }
        }
    }

    private var buttonTitle: String {
        guard page.isLast else { return "dalej" }
        return onFinish == nil ? "gotowe" : "dalej"
    }

    /// Back to the card before, or – on the first card inside the welcome – to the step before.
    private var backAction: (() -> Void)? {
        if page.rawValue > 0 {
            return { turn(by: -1) }
        }
        return onBack
    }

    private var pageTransition: AnyTransition {
        let shift: CGFloat = reduceMotion ? 0 : (isMovingForward ? 28 : -28)
        return .asymmetric(insertion: .opacity.combined(with: .offset(x: shift, y: 0)),
                           removal: .opacity)
    }

    private func turn(by delta: Int) {
        guard let target = TutorialPage(rawValue: page.rawValue + delta) else { return }
        isMovingForward = delta > 0
        withAnimation(reduceMotion ? Animation.easeInOut(duration: 0.2) : Animation.smooth(duration: 0.35)) {
            page = target
        }
    }

    private func advance() {
        if page.isLast {
            finish()
        } else {
            turn(by: 1)
        }
    }

    /// Done or skipped: seen either way. Written only when it changes anything.
    private func finish() {
        if !store.hasSeenTutorial && store.isEditable {
            store.setTutorialSeen()
        }
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }
}

/// The guide's cards, in order.
nonisolated enum TutorialPage: Int, CaseIterable {
    case saving, swipe, scale, star, places

    var isLast: Bool {
        self == TutorialPage.allCases.last
    }

    var title: String {
        switch self {
        case .saving: "zapisuję sama"
        case .swipe: "przesuń w lewo, żeby usunąć"
        case .scale: "przeciągnij od 1 do 10"
        case .star: "gwiazdka to działanie"
        case .places: "pięć miejsc"
        }
    }

    /// One short line – the example below shows the rest.
    var text: String {
        switch self {
        case .saving:
            "bez przycisku „zapisz” – zapisuję, gdy tylko skończysz"
        case .swipe:
            "pod spodem czeka kosz. Spróbuj – tu nic nie zginie"
        case .scale:
            "tak ustawiasz energię, nastrój i sen – albo dotknij skali"
        case .star:
            "gdzie gwiazdka, tam coś się dzieje – dotknij"
        case .places:
            "dotknij zakładki, a powiem, co w niej znajdziesz"
        }
    }
}

/// One card: what to do, in a heading and a line, and the example to try it on.
private struct TutorialCard: View {
    let page: TutorialPage
    /// +1 for the next card, −1 for the one before.
    let onSwipe: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    Text(polish: page.title)
                        .screenTitle()
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(polish: page.text)
                        .bodyText()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                // Only the text turns the cards: the examples below keep their own drags.
                .simultaneousGesture(swipe)
                example
            }
            .padding(.horizontal, Spacing.card)
            .padding(.top, Spacing.cardGap)
            .padding(.bottom, Spacing.group)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var example: some View {
        switch page {
        case .saving: TutorialTypingDemo()
        case .swipe: TutorialSwipeDemo()
        case .scale: TutorialScaleDemo()
        case .star: TutorialStarDemo()
        case .places: TutorialPlacesDemo()
        }
    }

    /// A clear sideways swipe; anything more up or down is left to scrolling.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let across = value.translation.width
                let down = value.translation.height
                guard abs(across) > 60, abs(across) > abs(down) * 1.5 else { return }
                onSwipe(across < 0 ? 1 : -1)
            }
    }
}

/// Where she is in the guide: a small star for this card, dots for the others.
private struct TutorialDots: View {
    let page: TutorialPage

    var body: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(TutorialPage.allCases, id: \.self) { item in
                if item == page {
                    OrganicStar()
                        .fill(Palette.accent)
                        .frame(width: 16, height: 16)
                } else {
                    // The cards behind her a little brighter than the ones ahead.
                    Circle()
                        .fill(item.rawValue < page.rawValue ? Palette.accent.opacity(0.55) : Color.white.opacity(0.22))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .frame(height: 16)
        .animation(.snappy(duration: 0.25), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "karta \(page.rawValue + 1) z \(TutorialPage.allCases.count)"))
    }
}
