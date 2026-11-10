import SwiftUI
import AboutHerCore

/// "pytanie do przemyślenia": one card from the deck. "inne pytanie" draws the next one – no card
/// comes back before the whole deck has been drawn. Her answer is kept with the question and the
/// day in "Twoje zapiski".
struct MomentQuestionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where she is in the deck.
    @Binding var position: Int
    @State private var isWriting = false
    /// She has just answered; shown until she draws the next card or writes again.
    @State private var hasSaved = false
    /// How far the question is turned while the next one is drawn: 0 facing her, 90 edge on.
    @State private var turn: Double = 0
    @State private var isDrawing = false

    var body: some View {
        let question = QuestionDeck.question(at: position)
        let number = QuestionDeck.cardNumber(at: position)
        let count = QuestionDeck.questions.count
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("pytanie do przemyślenia") {
                    Text(verbatim: "\(number) z \(count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                        .accessibilityLabel(Text(verbatim: "karta \(number) z \(count)"))
                }
                MomentQuestionFace(question: question)
                    .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                if isWriting {
                    MomentNoteField(target: .new(kind: .answer, prompt: question),
                                    placeholder: "napisz, co przychodzi Ci do głowy",
                                    hint: "zapiszę ją razem z pytaniem, gdy schowasz klawiaturę",
                                    onClose: { saved in
                                        withAnimation(.smooth) {
                                            isWriting = false
                                            hasSaved = saved
                                        }
                                    })
                } else {
                    if hasSaved {
                        ConfirmationNote(text: "zapisałam ją w Twoich zapiskach")
                    }
                    MomentActionRow {
                        StarActionButton("odpowiedz", size: .regular, action: startWriting)
                        StarActionButton("inne pytanie", size: .regular, action: draw)
                    }
                }
            }
        }
    }

    private func startWriting() {
        hasSaved = false
        isWriting = true
    }

    /// The question turns edge on, the next one takes its place and turns to face her.
    private func draw() {
        guard !isDrawing else { return }
        hasSaved = false
        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.3)) {
                position &+= 1
            }
            return
        }
        isDrawing = true
        withAnimation(.easeIn(duration: 0.2)) {
            turn = 90
        }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            position &+= 1
            withAnimation(.easeOut(duration: 0.25)) {
                turn = 0
            }
            isDrawing = false
        }
    }
}

/// The question itself, framed by the app's star above and a smaller one below – the face of
/// the card, right on the card (no card inside a card).
private struct MomentQuestionFace: View {
    let question: String

    var body: some View {
        VStack(spacing: Spacing.item) {
            OrganicStar()
                .fill(Palette.accent)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text(polish: question)
                .displayFont(21, italic: true, relativeTo: .title3)
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            OrganicStar()
                .fill(Palette.accentDim.opacity(0.6))
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.tight)
    }
}
