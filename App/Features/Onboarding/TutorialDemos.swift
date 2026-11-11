import SwiftUI
import AboutHerCore

// The guide's live examples. Each keeps its own little state and never touches her data; it starts
// afresh whenever its card shows again.

/// "zapisuję sama": a meal she can tap and correct; closing the field saves it, with a word of
/// confirmation and nothing to press.
struct TutorialTypingDemo: View {
    @State private var meal = "owsianka z malinami"
    @State private var draft = ""
    @State private var isEditing = false
    /// The open field has had the keyboard: only losing it after that closes the field.
    @State private var hadFocus = false
    @State private var saves = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("śniadanie")
                if isEditing {
                    TextField("co zjadłaś?", text: $draft)
                        .font(.body)
                        .foregroundStyle(Palette.text)
                        .submitLabel(.done)
                        .focused($isFocused)
                        .onSubmit(close)
                        .fieldBox()
                        .onAppear {
                            // Once more when the field is really there, in case the first ask came too early.
                            isFocused = true
                        }
                } else {
                    Button(action: open) {
                        ListRow(meal, detail: "dotknij, żeby poprawić")
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if saves > 0 && !isEditing {
                    ConfirmationNote(text: "zapisałam – bez żadnego przycisku")
                }
            }
            .animation(.smooth(duration: 0.25), value: isEditing)
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                hadFocus = true
            } else if hadFocus {
                // The keyboard went away: she is done, so it saves.
                close()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: saves)
    }

    private func open() {
        draft = meal
        hadFocus = false
        isEditing = true
        isFocused = true
    }

    private func close() {
        guard isEditing else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            meal = trimmed
        }
        isEditing = false
        isFocused = false
        saves += 1
    }
}

/// "przesuń w lewo, żeby usunąć": three made-up workouts with the real swipe and bin, and a way to
/// bring them back.
struct TutorialSwipeDemo: View {
    private static let rows = ["spacer · 30 min", "joga · 15 min", "rower · 20 min"]
    @State private var shown = TutorialSwipeDemo.rows

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("Twój ruch")
                if shown.isEmpty {
                    EmptyState(title: "pusto – właśnie tak to działa", actionTitle: "przywróć", action: restore)
                } else {
                    VStack(spacing: 0) {
                        ForEach(shown, id: \.self) { row in
                            ListRow(row, detail: "dziś")
                                .swipeToDelete(label: "usuń") {
                                    remove(row)
                                }
                            if row != shown.last {
                                RowDivider()
                            }
                        }
                    }
                    if shown.count < Self.rows.count {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                            ConfirmationNote(text: "usunięte")
                            Spacer(minLength: Spacing.tight)
                            Button("przywróć", action: restore)
                                .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
                        }
                    }
                }
            }
        }
    }

    private func remove(_ row: String) {
        withAnimation(.snappy) {
            shown.removeAll { $0 == row }
        }
    }

    private func restore() {
        withAnimation(.smooth(duration: 0.3)) {
            shown = Self.rows
        }
    }
}

/// "przeciągnij od 1 do 10": the real scale, set by dragging or a tap anywhere on it.
struct TutorialScaleDemo: View {
    private static let words = [ScaleWord(1...3, "niska"), ScaleWord(4...7, "średnia"), ScaleWord(8...10, "wysoka")]
    @State private var energy: Int? = nil

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                DragScale("energia", value: $energy, words: Self.words)
                if energy != nil {
                    ConfirmationNote(text: "tak właśnie – zapisuję od razu, krok po kroku")
                }
            }
            .animation(.smooth(duration: 0.25), value: energy == nil)
        }
    }
}

/// "gwiazdka to działanie": the large star action and the small star, both answering a tap.
struct TutorialStarDemo: View {
    @State private var taps = 0

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                StarActionButton("dopisz", size: .regular) {
                    taps += 1
                }
                HStack(spacing: Spacing.tight) {
                    StarButton(label: "dodaj", prominent: true) {
                        taps += 1
                    }
                    Text("mała gwiazdka też coś robi")
                        .rowDetail()
                }
                if taps > 0 {
                    ConfirmationNote(text: taps == 1 ? "właśnie tak" : "i jeszcze raz – działa")
                }
            }
            .animation(.smooth(duration: 0.25), value: taps > 0)
        }
    }
}

/// The five tabs, as in the app's tab bar.
nonisolated enum TutorialPlace: CaseIterable {
    case today, calendar, food, movement, me

    var title: String {
        switch self {
        case .today: "dziś"
        case .calendar: "kalendarz"
        case .food: "jedzenie"
        case .movement: "ruch"
        case .me: "ja"
        }
    }

    /// The same symbols as the tab bar (RootView).
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .calendar: "calendar"
        case .food: "fork.knife"
        case .movement: "figure.yoga"
        case .me: "sparkles"
        }
    }

    var detail: String {
        switch self {
        case .today: "Twój dzień: dzień cyklu, samopoczucie i to, co Ci dziś posłuży"
        case .calendar: "okres i fazy cyklu – dotknięciem zaznaczasz dni okresu"
        case .food: "posiłki wpisane zwykłym tekstem, woda, waga i Twoje cele"
        case .movement: "ruch na dziś, dopasowany do fazy cyklu"
        case .me: "chwila dla siebie, humor, wnętrze, list do siebie i ustawienia"
        }
    }
}

/// "pięć miejsc": a small copy of the tab bar; a tap on a tab says what is in it.
struct TutorialPlacesDemo: View {
    @State private var selected = TutorialPlace.today

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                HStack(spacing: 0) {
                    ForEach(TutorialPlace.allCases, id: \.self) { place in
                        placeButton(place)
                    }
                }
                .padding(Spacing.hairline)
                .background {
                    Capsule().fill(Color.white.opacity(0.05))
                }
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                }
                Text(polish: selected.detail)
                    .bodyText()
                    .id(selected)
                    .transition(.opacity)
            }
            .animation(.smooth(duration: 0.25), value: selected)
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func placeButton(_ place: TutorialPlace) -> some View {
        let isSelected = place == selected
        return Button {
            selected = place
        } label: {
            VStack(spacing: Spacing.hairline) {
                Image(systemName: place.symbol)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(place.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? Palette.accent : Palette.text2)
            .frame(maxWidth: .infinity, minHeight: TapSize.large)
            .background {
                if isSelected {
                    Capsule().fill(Color.white.opacity(0.09))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(place.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
