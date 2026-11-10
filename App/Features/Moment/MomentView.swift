import SwiftUI
import AboutHerCore

/// "chwila dla siebie", opened from "ja": one calm flow. First her mood and a meditation picked
/// for it and the part of the day, then an intention to take along, a breathing exercise, a
/// question card to sit with, and – quietly, at the end – what she wrote here.
///
/// The mood is today's mood from "dziś": set here, it is saved there too.
struct MomentView: View {
    @Environment(AppStore.self) private var store
    /// How many times she asked for another intention.
    @State private var intentionTurns = 0
    /// Where she is in the shuffled deck of question cards. The deck itself is never stored, and
    /// this number says nothing about her, so it lives with the app's settings, not in her data.
    @AppStorage("momentDeckPosition") private var deckPosition = 0

    var body: some View {
        let today = store.today
        let mood = store.data.symptoms(on: today).mood
        let time = MeditationTime(hour: Calendar.current.component(.hour, from: Date()))
        Screen {
            ScreenHeader(title: "chwila dla siebie", subtitle: Self.subtitle(for: time))
            MomentMeditationCard(time: time, mood: mood) { value in
                _ = store.setSymptomScale(\.mood, to: value, on: today)
            }
            MomentIntentionCard(intention: MeditationGuide.intention(for: mood, on: today, offset: intentionTurns),
                                onSwap: { intentionTurns &+= 1 })
            BreathingCard()
            MomentQuestionCard(position: $deckPosition)
            MomentNotesCard()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// What the moment is for at this part of the day.
    static func subtitle(for time: MeditationTime) -> String {
        switch time {
        case .morning: "na dobry początek dnia"
        case .day: "na chwilę oddechu w środku dnia"
        case .evening: "na wyciszenie przed snem"
        }
    }
}

/// The actions of a card side by side, or one under another when they don't fit (large text).
struct MomentActionRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.tight) {
                content
            }
            VStack(alignment: .leading, spacing: Spacing.tight) {
                content
            }
        }
    }
}

/// "Twoje zapiski": her answers and intentions from "chwila dla siebie", newest first, each with
/// its day. A tap opens one in place to correct it; a swipe to the left deletes it. A quiet card
/// at the end of the screen, there only once she has written something.
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
        if !notes.isEmpty {
            Card(style: .quiet) {
                VStack(alignment: .leading, spacing: Spacing.item) {
                    SectionHeader("Twoje zapiski")
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(shown) { note in
                            if note.id != shown.first?.id {
                                RowDivider()
                            }
                            noteRow(note)
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

    @ViewBuilder
    private func noteRow(_ note: MomentNote) -> some View {
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
                .padding(.vertical, Spacing.tight)
        } else {
            ListRow(note.text, detail: detail(of: note))
                .swipeToDelete(label: "usuń zapisek", onTap: { editingID = note.id }) {
                    store.removeMomentNote(note.id)
                }
        }
    }

    /// "dziś · intencja", or for an answer its day and the question: "wczoraj · co chroni Twój spokój?".
    private func detail(of note: MomentNote) -> String {
        let day = Self.dayText(note.day, today: store.today)
        switch note.kind {
        case .answer:
            return note.prompt.isEmpty ? "\(day) · odpowiedź" : "\(day) · \(note.prompt)"
        case .intention:
            return "\(day) · intencja"
        }
    }

    /// "dziś", "wczoraj", otherwise "7 listopada" – with the year when it isn't this year.
    private static func dayText(_ day: LocalDate, today: LocalDate) -> String {
        if day == today {
            return "dziś"
        }
        if day == today.adding(days: -1) {
            return "wczoraj"
        }
        if day.year == today.year {
            return PolishDate.dayMonth(day)
        }
        return "\(PolishDate.dayMonth(day)) \(day.year)"
    }
}
