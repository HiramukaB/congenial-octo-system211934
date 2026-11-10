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

    var body: some View {
        let today = store.today
        let open = store.data.openLetters(on: today)
        let sealed = store.data.sealedLetters(on: today)
        Screen {
            Text("list do siebie").screenTitle()
            Text(polish: "napisz kilka słów do przyszłej siebie. Zapieczętuję list do dnia, który wybierzesz – wcześniej go nie przeczytasz")
                .bodyText()
            Button(action: startWriting) {
                Card {
                    HStack(spacing: 12) {
                        OrganicStar()
                            .fill(Palette.accent)
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("napisz list").sectionTitle()
                            Text(polish: "otworzysz go za miesiąc, za 3 miesiące, za pół roku albo w dniu, który wybierzesz")
                                .font(.footnote)
                                .foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .buttonStyle(.plain)
            if !open.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("otwarte").sectionTitle()
                        ForEach(open) { letter in
                            openRow(letter, today: today)
                        }
                    }
                }
            }
            if !sealed.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("zapieczętowane").sectionTitle()
                        ForEach(sealed) { letter in
                            sealedRow(letter, today: today)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isWriting) {
            LetterWritingSheet()
        }
    }

    /// A letter she can read: a tap opens it and closes it again.
    private func openRow(_ letter: Letter, today: LocalDate) -> some View {
        let isRead = readIDs.contains(letter.id)
        return VStack(alignment: .leading, spacing: 4) {
            Text("list z \(InnerFormat.date(letter.writtenOn, today: today))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.text)
            if isRead {
                Text(letter.text)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("otworzył się \(InnerFormat.day(letter.opensOn, today: today)) · dotknij, żeby przeczytać")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .swipeToDelete(label: "usuń list", onTap: { toggleReading(letter.id) }) {
            store.removeLetter(letter.id)
        }
    }

    /// A sealed letter shows only when it opens.
    private func sealedRow(_ letter: Letter, today: LocalDate) -> some View {
        let days = today.days(to: letter.opensOn)
        let countdown = days == 1 ? "jutro" : "za \(PolishPlural.days(days))"
        return VStack(alignment: .leading, spacing: 3) {
            Text("otworzysz \(InnerFormat.date(letter.opensOn, today: today))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.text)
            Text("\(countdown) · napisany \(InnerFormat.day(letter.writtenOn, today: today))")
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .swipeToDelete(label: "usuń list") {
            store.removeLetter(letter.id)
        }
    }

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
}

/// "nowy list": the day it opens and the letter. Closing the sheet – swiped down or "gotowe" –
/// seals it; an empty one isn't kept. When the app goes to the background the letter is saved as
/// it is, and closing later saves the rest.
private struct LetterWritingSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var letterID = UUID()
    @State private var text = ""
    @State private var opening = LetterOpening.threeMonths
    @State private var chosenDate = LetterCalendar.date(Letter.defaultOpeningDay(writtenOn: .today()))
    /// What is in her data already; nil until the letter is first saved.
    @State private var saved: LetterSaved? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        let today = store.today
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("kiedy go otworzysz").sectionTitle()
                    Picker("kiedy go otworzysz", selection: $opening) {
                        ForEach(LetterOpening.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    if opening == .chosenDay {
                        DatePicker("dzień otwarcia",
                                   selection: $chosenDate,
                                   in: LetterCalendar.date(today.adding(days: 1))...,
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(Palette.accent)
                            .environment(\.locale, Locale(identifier: "pl_PL"))
                    }
                    Text(polish: "otworzysz go \(InnerFormat.date(openingDay(today: today), today: today)). Zapieczętuję list, gdy zamkniesz tę kartkę")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("napisz coś do siebie. Przeczytasz to za jakiś czas – i pewnie będziesz już gdzie indziej",
                              text: $text, axis: .vertical)
                        .font(.body)
                        .foregroundStyle(Palette.text)
                        .lineLimit(12...)
                        .focused($isFocused)
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Palette.accentBackground.opacity(0.6))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1)
                        }
                        .onAppear {
                            isFocused = true
                        }
                }
                .padding(20)
            }
            // Dragging down into the keyboard closes it; the letter stays as it is.
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background)
            .navigationTitle("nowy list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Closing seals the letter (see onDisappear), so "gotowe" only closes.
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("gotowe")
                }
            }
        }
        .presentationDetents([.large])
        .onDisappear {
            seal()
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: keep the letter as it is now.
            if phase == .background {
                seal()
                store.saveNow()
            }
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

    /// Seals the letter as it is now. Emptied after it was saved in the background, it goes again.
    private func seal() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if saved != nil {
                store.removeLetter(letterID)
                saved = nil
            }
            return
        }
        let current = LetterSaved(text: trimmed, opensOn: openingDay(today: store.today))
        guard current != saved else { return }
        if store.sealLetter(id: letterID, text: current.text, opensOn: current.opensOn) {
            saved = current
        }
    }
}

/// A letter as it was last saved.
private struct LetterSaved: Equatable {
    let text: String
    let opensOn: LocalDate
}

/// When a new letter opens.
private enum LetterOpening: CaseIterable, Hashable {
    case oneMonth, threeMonths, sixMonths, chosenDay

    var label: String {
        switch self {
        case .oneMonth: "miesiąc"
        case .threeMonths: "3 miesiące"
        case .sixMonths: "pół roku"
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
