import SwiftUI
import AboutHerCore

/// "pytanie do przemyślenia": one card from the deck. The star draws the next one – no card comes
/// back before the whole deck has been drawn. Her answer is kept with the question and the date.
struct MomentQuestionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Where she is in the deck.
    @Binding var position: Int
    @State private var isWriting = false
    /// She has just answered; shown until she draws the next card.
    @State private var hasSaved = false
    /// How far the card is turned while the next one is drawn: 0 facing her, 90 edge on.
    @State private var turn: Double = 0
    @State private var isDrawing = false

    var body: some View {
        let question = QuestionDeck.question(at: position)
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("pytanie do przemyślenia").sectionTitle()
                    Spacer()
                    // Hidden while she writes, so her answer stays with the question she sees.
                    if !isWriting {
                        StarButton(label: "wyciągnij kolejną kartę", action: draw)
                    }
                }
                MomentQuestionFace(question: question,
                                   number: QuestionDeck.cardNumber(at: position),
                                   count: QuestionDeck.questions.count)
                    .rotation3DEffect(.degrees(turn), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                if isWriting {
                    MomentNoteField(target: .new(kind: .answer, prompt: question),
                                    placeholder: "napisz, co przychodzi Ci do głowy",
                                    hint: "zapiszę Twoją odpowiedź razem z pytaniem, gdy schowasz klawiaturę",
                                    onClose: { saved in
                                        isWriting = false
                                        hasSaved = saved
                                    })
                } else {
                    if hasSaved {
                        Text(polish: "zapisałam ją w Twoich zapiskach, na dole")
                            .font(.footnote)
                            .foregroundStyle(Palette.accent)
                    }
                    Button("odpowiedz na to pytanie") {
                        hasSaved = false
                        isWriting = true
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    /// The card turns edge on, the next one takes its place and turns to face her.
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

/// The face of a question card: the app's star above the question and a smaller one below,
/// on a card of the app's own colours.
struct MomentQuestionFace: View {
    let question: String
    /// Which card of the deck this is, of `count`.
    let number: Int
    let count: Int

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 16) {
            OrganicStar()
                .fill(Palette.accent)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            Text(polish: question)
                .displayFont(21, italic: true, relativeTo: .title3)
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            OrganicStar()
                .fill(Palette.accentDim.opacity(0.6))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background {
            shape.fill(LinearGradient(colors: [Palette.accentBackground, Palette.card.opacity(0.9)],
                                      startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            shape.strokeBorder(Palette.accent.opacity(0.25), lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(verbatim: "\(number) / \(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Palette.muted)
                .padding(12)
                // VoiceOver would read the slash.
                .accessibilityLabel(Text(verbatim: "karta \(number) z \(count)"))
        }
        .accessibilityElement(children: .combine)
    }
}
