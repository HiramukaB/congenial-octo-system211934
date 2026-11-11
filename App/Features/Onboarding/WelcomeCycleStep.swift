import SwiftUI
import AboutHerCore

/// "kiedy zaczął się ostatni okres?": a tap on its first day and a drag for about how many days it
/// lasts. The days are marked in the calendar at once, as she answers; a changed answer takes back
/// only what this step marked, never a day she marked herself.
///
/// With periods already marked (her data from before the welcome, or a welcome she left midway),
/// the step shows the last one to confirm – and she can still add a newer one.
struct WelcomeCycleStep: View {
    @Environment(AppStore.self) private var store
    @Binding var memory: WelcomeMemory
    let onBack: () -> Void
    let onNext: () -> Void

    /// The month the grid shows.
    @State private var month = LocalDate.today().firstOfMonth
    @State private var hasLoaded = false

    /// About how long a period lasts when nothing else is known.
    private static let usualLength = 5

    var body: some View {
        let hasEarlierMarks = !store.data.periodDays.subtracting(memory.markedDays).isEmpty
        let isChoosing = !hasEarlierMarks || memory.isAddingNewerPeriod || memory.periodStart != nil
        WelcomePage(step: .cycle,
                    title: isChoosing ? "kiedy zaczął się ostatni okres?" : "Twój cykl",
                    subtitle: isChoosing
                        ? "zaznaczę te dni w kalendarzu i policzę fazy cyklu"
                        : "to już wiem – sprawdź, czy się zgadza",
                    canSkip: isChoosing && memory.periodStart == nil,
                    onBack: onBack,
                    onNext: onNext) {
            if isChoosing {
                chooser
            } else {
                summary
            }
        }
        .onAppear(perform: load)
        .onDisappear {
            // "zaznacz nowszy okres" left without a day: next time, what is already there.
            if memory.periodStart == nil {
                memory.isAddingNewerPeriod = false
            }
        }
    }

    // MARK: - Choosing

    private var chooser: some View {
        let today = store.today
        let length = memory.periodLength ?? Self.usualLength
        let chosen: ClosedRange<LocalDate>? = memory.periodStart.map { start in
            start...Swift.max(start, Swift.min(start.adding(days: length - 1), today))
        }
        return VStack(alignment: .leading, spacing: Spacing.group) {
            Card {
                WelcomeMonthGrid(month: $month, today: today, marked: store.data.periodDays,
                                 chosen: chosen, onSelect: select)
            }
            if let start = memory.periodStart {
                DragScale("ile dni zwykle trwa", value: length, range: 1...10) { value in
                    setLength(value)
                }
                answer(start: start, length: length, today: today)
            }
        }
        .animation(.smooth(duration: 0.25), value: memory.periodStart)
    }

    /// What she has just marked, and what follows from it.
    private func answer(start: LocalDate, length: Int, today: LocalDate) -> some View {
        let planned = start.adding(days: Swift.max(length, 1) - 1)
        let end = Swift.max(start, Swift.min(planned, today))
        let count = start.days(to: end) + 1
        let expected = upcomingPeriod(today: today)
        return VStack(alignment: .leading, spacing: Spacing.tight) {
            ConfirmationNote(text: "zaznaczyłam \(PolishPlural.days(count)): \(PolishDate.range(start, end))")
            if planned > today {
                Text(polish: "kolejne dni zaznaczysz w kalendarzu")
                    .hintText()
            } else if let expected {
                Text(polish: "następny okres spodziewam się około \(PolishDate.dayMonth(expected))")
                    .hintText()
            }
        }
    }

    // MARK: - What is already there

    private var summary: some View {
        let today = store.today
        let engine = store.cycle
        let last = engine.status(on: today).lastPeriod ?? engine.bleeding.last
        let expected = upcomingPeriod(today: today)
        return VStack(alignment: .leading, spacing: Spacing.group) {
            if let last {
                Card(style: .highlight) {
                    VStack(alignment: .leading, spacing: Spacing.cardGap) {
                        SectionHeader("ostatni okres")
                        VStack(alignment: .leading, spacing: Spacing.hairline) {
                            Text(PolishDate.dayMonth(last.start))
                                .displayFont(30, weight: .medium, relativeTo: .title)
                                .foregroundStyle(Palette.text)
                            Text(polish: summaryLine(last, expected: expected))
                                .bodyText()
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            // A real button, easy to hit, for the one other thing she may want here.
            VStack(alignment: .leading, spacing: Spacing.item) {
                StarActionButton("zaznacz nowszy okres", size: .regular, action: startNewer)
                Text(polish: "pojedyncze dni poprawisz w kalendarzu")
                    .hintText()
            }
        }
    }

    /// When the next period is expected – only while that day is still ahead (a late or long
    /// unmarked cycle has nothing to promise).
    private func upcomingPeriod(today: LocalDate) -> LocalDate? {
        guard let expected = store.cycle.status(on: today).prediction?.expected, expected >= today else {
            return nil
        }
        return expected
    }

    /// "5 dni · następny około 1 grudnia"
    private func summaryLine(_ period: PeriodRange, expected: LocalDate?) -> String {
        let days = PolishPlural.days(period.length)
        guard let expected else { return days }
        return "\(days) · następny około \(PolishDate.dayMonth(expected))"
    }

    // MARK: - Changes

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        month = (memory.periodStart ?? store.today).firstOfMonth
        if memory.periodLength == nil {
            let typical = store.cycle.stats.typicalPeriodLength
            memory.periodLength = Swift.min(Swift.max(typical, 1), 10)
        }
    }

    private func startNewer() {
        month = store.today.firstOfMonth
        withAnimation(.smooth(duration: 0.25)) {
            memory.isAddingNewerPeriod = true
        }
    }

    /// A tap on a day makes it the first day; a second tap on the first day takes the answer back.
    private func select(_ day: LocalDate) {
        let start: LocalDate? = day == memory.periodStart ? nil : day
        let length = memory.periodLength ?? Self.usualLength
        guard let added = store.markWelcomePeriod(startingOn: start, days: length, replacing: memory.markedDays) else {
            return
        }
        memory.markedDays = added
        memory.periodStart = start
    }

    /// Every step of the scale marks the days again. "wyczyść" goes back to the usual length.
    private func setLength(_ value: Int?) {
        let length = value ?? Self.usualLength
        memory.periodLength = length
        guard let start = memory.periodStart,
              let added = store.markWelcomePeriod(startingOn: start, days: length, replacing: memory.markedDays)
        else { return }
        memory.markedDays = added
    }
}

/// One month to pick a day from: Monday first, today outlined, the days she marked before softly
/// filled, the days of her answer filled with the accent. Days after today can't be picked.
private struct WelcomeMonthGrid: View {
    @Binding var month: LocalDate
    let today: LocalDate
    let marked: Set<LocalDate>
    let chosen: ClosedRange<LocalDate>?
    let onSelect: (LocalDate) -> Void

    var body: some View {
        let first = month.firstOfMonth
        let leading = first.isoWeekday - 1
        let count = LocalDate.daysInMonth(year: first.year, month: first.month)
        VStack(spacing: Spacing.item) {
            HStack(spacing: 0) {
                monthButton("poprzedni miesiąc", symbol: "chevron.left", isEnabled: true) {
                    month = first.addingMonths(-1)
                }
                Text(PolishDate.monthYear(first))
                    .displayFont(19, weight: .medium, relativeTo: .headline)
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity)
                monthButton("następny miesiąc", symbol: "chevron.right", isEnabled: first < today.firstOfMonth) {
                    month = first.addingMonths(1)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(0..<7, id: \.self) { index in
                    Text(PolishDate.weekdayInitials[index])
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                ForEach(0..<(leading + count), id: \.self) { index in
                    if index < leading {
                        Color.clear
                            .frame(height: TapSize.minimum)
                            .accessibilityHidden(true)
                    } else {
                        dayCell(first.adding(days: index - leading))
                    }
                }
            }
            // The numbers sit in fixed circles; beyond this size they would no longer fit.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .sensoryFeedback(.selection, trigger: chosen?.lowerBound)
    }

    private func monthButton(_ label: String, symbol: String, isEnabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: TapSize.minimum, height: TapSize.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.25)
        .accessibilityLabel(Text(label))
    }

    private func dayCell(_ date: LocalDate) -> some View {
        let isChosen = chosen?.contains(date) ?? false
        let isMarked = marked.contains(date)
        let isFuture = date > today
        let isToday = date == today
        return Button {
            onSelect(date)
        } label: {
            Text(String(date.day))
                .font(.body.weight(isChosen ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(numberColor(isChosen: isChosen, isFuture: isFuture, isToday: isToday))
                .frame(width: 38, height: 38)
                .background {
                    marker(isChosen: isChosen, isMarked: isMarked, isToday: isToday)
                }
                .frame(maxWidth: .infinity, minHeight: TapSize.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(WelcomeDayStyle())
        .disabled(isFuture)
        .accessibilityLabel(Text(spokenDay(date, isChosen: isChosen, isMarked: isMarked, isToday: isToday)))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    @ViewBuilder
    private func marker(isChosen: Bool, isMarked: Bool, isToday: Bool) -> some View {
        if isChosen {
            Circle().fill(Palette.accent)
        } else if isMarked {
            Circle().fill(Palette.accent.opacity(0.28))
        } else if isToday {
            Circle().strokeBorder(Palette.accentDim, lineWidth: 1)
        }
    }

    private func numberColor(isChosen: Bool, isFuture: Bool, isToday: Bool) -> Color {
        if isChosen {
            return Palette.onAccent
        }
        if isFuture {
            return Palette.muted.opacity(0.5)
        }
        return isToday ? Palette.text : Palette.text2
    }

    /// "3 listopada, pierwszy dzień okresu, dziś"
    private func spokenDay(_ date: LocalDate, isChosen: Bool, isMarked: Bool, isToday: Bool) -> String {
        var parts = [PolishDate.dayMonth(date)]
        if date == chosen?.lowerBound {
            parts.append("pierwszy dzień okresu")
        } else if isChosen {
            parts.append("okres")
        } else if isMarked {
            parts.append("okres zaznaczony wcześniej")
        }
        if isToday {
            parts.append("dziś")
        }
        return parts.joined(separator: ", ")
    }
}

/// Like `.plain`, without dimming the days after today a second time – their colour says it.
private struct WelcomeDayStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
