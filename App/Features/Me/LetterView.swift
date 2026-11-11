import SwiftUI
import AboutHerCore

/// "list do siebie", opened from "ja": letters to herself, each sealed until the day she chose
/// (three months by default). A sealed letter shows only when it opens; from that day on a tap
/// opens it. A swipe to the left removes a letter.
struct LetterView: View {
    @Environment(AppStore.self) private var store
    @State private var isWriting = false
    /// The open letters she tapped to read, on this visit.
    @State private var readIDs: Set<UUID> = []
    /// "zapieczętowałam…" for a moment after the sheet closed with a sealed letter.
    @State private var sealedNote: String? = nil
    @State private var seals = 0

    var body: some View {
        let today = store.today
        let open = store.data.openLetters(on: today)
        let sealed = store.data.sealedLetters(on: today)
        Screen {
            ScreenHeader(title: "list do siebie", subtitle: "zapieczętuję go do dnia, który wybierzesz")
            if open.isEmpty && sealed.isEmpty {
                Card {
                    EmptyState(title: "napisz kilka słów do przyszłej siebie",
                               actionTitle: "napisz list",
                               action: { startWriting() })
                }
            } else {
                StarActionButton("napisz list") {
                    startWriting()
                }
            }
            if let sealedNote {
                ConfirmationNote(text: sealedNote)
            }
            if !open.isEmpty {
                openCard(open, today: today)
            }
            if !sealed.isEmpty {
                sealedCard(sealed, today: today)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isWriting) {
            LetterWritingSheet { opensOn in
                showSealed(opensOn)
            }
        }
        .task(id: seals) {
            guard seals > 0 else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) {
                sealedNote = nil
            }
        }
    }

    // MARK: - Open letters

    /// Letters she can read now – the reason to come here, so they stand out.
    private func openCard(_ letters: [Letter], today: LocalDate) -> some View {
        Card(style: .highlight) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("otwarte")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(letters) { letter in
                        if letter.id != letters.first?.id {
                            RowDivider()
                        }
                        openRow(letter, today: today)
                    }
                }
            }
        }
    }

    /// A letter she can read: a tap opens it in place and closes it again.
    private func openRow(_ letter: Letter, today: LocalDate) -> some View {
        let isRead = readIDs.contains(letter.id)
        return VStack(alignment: .leading, spacing: 0) {
            ListRow("list z \(InnerFormat.date(letter.writtenOn, today: today))",
                    detail: "otworzył się \(InnerFormat.day(letter.opensOn, today: today))") {
                Image(systemName: isRead ? "envelope.open" : "envelope")
                    .font(.body)
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
            }
            if isRead {
                Text(polish: letter.text)
                    .displayFont(19, italic: true, relativeTo: .body)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.item)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .swipeToDelete(label: "usuń list", onTap: { toggleReading(letter.id) }) {
            store.removeLetter(letter.id)
        }
        .accessibilityHint(Text(isRead ? "zwija list" : "otwiera list do przeczytania"))
    }

    // MARK: - Sealed letters

    private func sealedCard(_ letters: [Letter], today: LocalDate) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("zapieczętowane")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(letters) { letter in
                        if letter.id != letters.first?.id {
                            RowDivider()
                        }
                        sealedRow(letter, today: today)
                    }
                }
            }
        }
    }

    /// A sealed letter shows only when it opens, and how long until then.
    private func sealedRow(_ letter: Letter, today: LocalDate) -> some View {
        let days = today.days(to: letter.opensOn)
        let countdown = days == 1 ? "jutro" : "za \(PolishPlural.days(days))"
        return ListRow("otworzysz \(InnerFormat.date(letter.opensOn, today: today))",
                       detail: "napisany \(InnerFormat.day(letter.writtenOn, today: today))") {
            Text(countdown)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Palette.accent)
        }
        .swipeToDelete(label: "usuń list") {
            store.removeLetter(letter.id)
        }
    }

    // MARK: - Changes

    /// The sheet opens only when her data can be changed, so a letter is never written for nothing.
    private func startWriting() {
        if store.acceptsChanges() {
            isWriting = true
        }
    }

    private func toggleReading(_ id: UUID) {
        withAnimation(.snappy) {
            if readIDs.contains(id) {
                readIDs.remove(id)
            } else {
                readIDs.insert(id)
            }
        }
    }

    private func showSealed(_ opensOn: LocalDate) {
        withAnimation(.smooth) {
            sealedNote = "zapieczętowałam list – otworzysz go \(InnerFormat.date(opensOn, today: store.today))"
        }
        seals += 1
    }
}

/// "nowy list": when it opens – four large choices, a calendar for "inny dzień" – and the letter.
/// Closing the sheet – swiped down or with the close button – seals it; an empty one isn't kept.
/// When the app goes to the background the letter is saved as it is, and closing later saves the
/// rest.
private struct LetterWritingSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// Called once the sheet has closed with the letter sealed, with the day it opens.
    let onSealed: (LocalDate) -> Void

    @State private var letterID = UUID()
    @State private var text = ""
    @State private var opening = LetterOpening.threeMonths
    @State private var chosenDate = LetterCalendar.date(Letter.defaultOpeningDay(writtenOn: .today()))
    /// What is in her data already; nil until the letter is first saved.
    @State private var saved: LetterSaved? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        let today = store.today
        let opensOn = openingDay(today: today)
        NavigationStack {
            Screen {
                ScreenHeader(title: "nowy list",
                             subtitle: "otworzysz go \(InnerFormat.date(opensOn, today: today))")
                VStack(alignment: .leading, spacing: Spacing.item) {
                    Text("kiedy go otworzysz")
                        .sectionTitle()
                        .accessibilityAddTraits(.isHeader)
                    ChoiceTiles(options: LetterOpening.allCases,
                                selection: opening,
                                columns: 2,
                                label: { option in option.label },
                                onSelect: { option in choose(option) })
                    if opening == .chosenDay {
                        DatePicker("dzień otwarcia",
                                   selection: $chosenDate,
                                   in: LetterCalendar.date(today.adding(days: 1))...,
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Palette.accent)
                            .environment(\.locale, Locale(identifier: "pl_PL"))
                            .transition(.opacity)
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    TextField("list",
                              text: $text,
                              prompt: Text("napisz coś do siebie – przeczytasz to, gdy będziesz już gdzie indziej")
                                  .foregroundStyle(Palette.muted),
                              axis: .vertical)
                        .font(.body)
                        .foregroundStyle(Palette.text)
                        .lineLimit(10...)
                        .focused($isFocused)
                        .fieldBox()
                        .onAppear {
                            isFocused = true
                        }
                    Text(polish: "zapieczętuję go, gdy zamkniesz kartkę")
                        .hintText()
                }
                .padding(.top, Spacing.tight)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Closing seals the letter (see onDisappear); there is nothing to confirm.
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("zamknij i zapieczętuj"))
                }
            }
        }
        .tint(Palette.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            if let opensOn = seal() {
                onSealed(opensOn)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: keep the letter as it is now.
            if phase == .background {
                seal()
                store.saveNow()
            }
        }
    }

    private func choose(_ option: LetterOpening) {
        withAnimation(.snappy(duration: 0.2)) {
            opening = option
        }
        if option == .chosenDay {
            // The calendar needs the room the keyboard takes.
            isFocused = false
        }
    }

    /// The day the letter opens – never before tomorrow, also when midnight passed while she wrote.
    private func openingDay(today: LocalDate) -> LocalDate {
        let day: LocalDate
        switch opening {
        case .oneMonth:
            day = today.addingMonths(1)
        case .threeMonths:
            day = Letter.defaultOpeningDay(writtenOn: today)
        case .sixMonths:
            day = today.addingMonths(6)
        case .chosenDay:
            day = LetterCalendar.day(chosenDate)
        }
        return Swift.max(day, today.adding(days: 1))
    }

    /// Seals the letter as it is now and returns the day it opens; nil when no letter is kept.
    /// Emptied after it was saved in the background, it goes again. Refused now, the version
    /// saved earlier stays sealed.
    @discardableResult
    private func seal() -> LocalDate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if saved != nil {
                store.removeLetter(letterID)
                saved = nil
            }
            return nil
        }
        let current = LetterSaved(text: trimmed, opensOn: openingDay(today: store.today))
        if current == saved {
            return current.opensOn
        }
        if store.sealLetter(id: letterID, text: current.text, opensOn: current.opensOn) {
            saved = current
            return current.opensOn
        }
        return saved?.opensOn
    }
}

/// A letter as it was last saved.
private struct LetterSaved: Equatable {
    let text: String
    let opensOn: LocalDate
}

/// When a new letter opens.
private nonisolated enum LetterOpening: CaseIterable, Hashable {
    case oneMonth, threeMonths, sixMonths, chosenDay

    var label: String {
        switch self {
        case .oneMonth: "za miesiąc"
        case .threeMonths: "za 3 miesiące"
        case .sixMonths: "za pół roku"
        case .chosenDay: "inny dzień"
        }
    }
}

/// Between her days and the dates of the system date picker. Noon, so a day never slips across
/// midnight.
private nonisolated enum LetterCalendar {
    static func date(_ day: LocalDate) -> Date {
        let parts = DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)
        return Calendar.current.date(from: parts) ?? Date()
    }

    static func day(_ date: Date) -> LocalDate {
        LocalDate.today(calendar: .current, now: date)
    }
}
