import SwiftUI
import AboutHerCore

/// "medytacja", the card the screen is about: her mood on the scale, and a meditation picked for
/// it and the part of the day, which the big star opens on YouTube (in the app when it is
/// installed, otherwise in Safari). The mood is today's: set here, it is saved on "dziś" too.
struct MomentMeditationCard: View {
    @Environment(\.openURL) private var openURL
    let time: MeditationTime
    /// Today's mood of 1–10, or nil.
    let mood: Int?
    /// A new mood from the scale (nil when she cleared it), saved as today's mood.
    let onMoodChange: (Int?) -> Void

    var body: some View {
        let meditation = MeditationGuide.meditation(for: time, mood: mood)
        Card(style: .highlight) {
            VStack(alignment: .leading, spacing: Spacing.group) {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    SectionHeader("medytacja")
                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        DragScale("nastrój", value: mood, words: SymptomScaleWords.mood, onChange: onMoodChange)
                        if mood == nil {
                            Text(polish: "dobiorę medytację do Twojego nastroju")
                                .hintText()
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.item) {
                    Text(polish: meditation.title)
                        .displayFont(20, relativeTo: .title3)
                        .foregroundStyle(Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                        .animation(.smooth, value: meditation)
                    StarActionButton("otwórz na YouTube", isEnabled: meditation.url != nil) {
                        open(meditation)
                    }
                }
            }
        }
    }

    private func open(_ meditation: Meditation) {
        guard let url = meditation.url else { return }
        openURL(url)
    }
}

/// "intencja": a few words to take into the meditation or the breathing, picked for her mood.
/// "inna" offers another; "napisz własną" opens a field for her own, kept in "Twoje zapiski".
struct MomentIntentionCard: View {
    let intention: String
    let onSwap: () -> Void
    @State private var isWriting = false
    /// She has just written her own; shown until she asks for another or writes again.
    @State private var hasSaved = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("intencja")
                Text(polish: intention)
                    .displayFont(22, italic: true, relativeTo: .title3)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                    .animation(.smooth, value: intention)
                if isWriting {
                    MomentNoteField(target: .new(kind: .intention, prompt: ""),
                                    placeholder: "np. dziś idę swoim tempem",
                                    hint: "zapiszę ją, gdy schowasz klawiaturę",
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
                        StarActionButton("inna", size: .regular, action: offerAnother)
                            .accessibilityLabel(Text("inna intencja"))
                        StarActionButton("napisz własną", size: .regular, action: startWriting)
                    }
                }
            }
        }
    }

    private func offerAnother() {
        hasSaved = false
        onSwap()
    }

    private func startWriting() {
        hasSaved = false
        isWriting = true
    }
}
