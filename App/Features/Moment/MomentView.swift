import SwiftUI
import AboutHerCore

/// "chwila dla siebie", opened from "ja": a meditation picked for the part of the day and her mood,
/// an intention to take into it, a calm breathing exercise, a question card to sit with, and what
/// she wrote here, each with its date.
struct MomentView: View {
    @Environment(AppStore.self) private var store
    /// The mood she tapped here; until then, the one she marked for today, if any. It only picks
    /// the meditation and the intention – her day on "dziś" is not changed from here.
    @State private var pickedMood: MoodLevel? = nil
    /// How many times she asked for another intention.
    @State private var intentionTurns = 0
    /// Where she is in the shuffled deck of question cards. The deck itself is never stored, and
    /// this number says nothing about her, so it lives with the app's settings, not in her data.
    @AppStorage("momentDeckPosition") private var deckPosition = 0

    var body: some View {
        let mood = pickedMood ?? store.data.symptoms(on: store.today).mood
        let time = MeditationTime(hour: Calendar.current.component(.hour, from: Date()))
        Screen {
            Text("chwila dla siebie").screenTitle()
            Text(polish: "kilka minut tylko dla Ciebie: medytacja, oddech i jedno pytanie do przemyślenia")
                .bodyText()
            MomentMeditationCard(time: time,
                                 mood: mood,
                                 isMoodFromToday: pickedMood == nil && mood != nil,
                                 onPickMood: { pickedMood = $0 })
            MomentIntentionCard(intention: MeditationGuide.intention(for: mood, on: store.today,
                                                                     offset: intentionTurns),
                                onSwap: { intentionTurns &+= 1 })
            BreathingCard()
            MomentQuestionCard(position: $deckPosition)
            MomentNotesCard()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "Twoje zapiski": her answers and intentions from "chwila dla siebie", newest first, each with
/// its date. A tap opens one in place to correct it; a swipe to the left deletes it.
struct MomentNotesCard: View {
    @Environment(AppStore.self) private var store
    /// The note open for correcting.
    @State private var editingID: UUID? = nil
    @State private var showsAll = false

    /// How many are shown before "pokaż wszystkie".
    private static let firstCount = 12

    var body: some View {
        let notes = Array(store.data.moments.reversed())
        let shown = showsAll ? notes : Array(notes.prefix(Self.firstCount))
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Twoje zapiski").sectionTitle()
                if notes.isEmpty {
                    Text(polish: "tu zbiorę Twoje odpowiedzi i intencje, każdą z datą, żebyś mogła do nich wracać")
                        .bodyText()
                }
                ForEach(shown) { note in
                    if editingID == note.id {
                        MomentNoteField(target: .existing(id: note.id, originalText: note.text),
                                        placeholder: "",
                                        hint: "zapiszę poprawkę, gdy schowasz klawiaturę",
                                        onClose: { _ in
                                            // Another note may already be open in its place.
                                            if editingID == note.id {
                                                editingID = nil
                                            }
                                        })
                    } else {
                        MomentNoteRow(note: note, today: store.today)
                            .swipeToDelete(label: "usuń zapisek", onTap: { editingID = note.id }) {
                                store.removeMomentNote(note.id)
                            }
                    }
                }
                if notes.count > shown.count {
                    Button("pokaż wszystkie (\(notes.count))") {
                        showsAll = true
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }
}

/// One thing she wrote: the day and what it is, the question if it answers one, and her words.
struct MomentNoteRow: View {
    let note: MomentNote
    let today: LocalDate

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: "\(dayText) · \(kindText)")
                .font(.caption)
                .foregroundStyle(Palette.muted)
            if !note.prompt.isEmpty {
                Text(polish: note.prompt)
                    .font(.footnote.italic())
                    .foregroundStyle(Palette.accentDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(note.text)
                .font(.subheadline)
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var dayText: String {
        note.day == today ? "dziś" : PolishDate.dayMonth(note.day)
    }

    private var kindText: String {
        switch note.kind {
        case .answer: "odpowiedź"
        case .intention: "intencja"
        }
    }
}
