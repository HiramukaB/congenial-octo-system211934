import SwiftUI
import AboutHerCore

nonisolated struct CalendarCell: Identifiable {
    let id: Int
    let date: LocalDate?
}

/// One month: its name with the steps to the months around it, the days in large cells (her
/// period, the forecast, the phases, a star on the days she noted how she felt) and a one-line
/// legend for what the chosen mode is about.
struct MonthCard: View {
    @Binding var month: LocalDate
    let engine: CycleEngine
    let periodDays: Set<LocalDate>
    /// The days she noted how she felt.
    let symptomDays: Set<LocalDate>
    let today: LocalDate
    @State var toggles = 0
    /// How she felt on a day: a long press on it, or a tap in the "samopoczucie" mode.
    let onShowSymptoms: (LocalDate) -> Void
    /// What a tap on a day does.
    var mode = CalendarTapMode.period
    let onToggle: (LocalDate) -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                header
                grid
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    CalendarLegend(mode: mode)
                    footer
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: toggles)
    }

    // MARK: - Parts

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.tight) {
            Text(PolishDate.monthYear(month))
                .displayFont(22, weight: .medium, relativeTo: .title3)
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.tight)
            if month.firstOfMonth != today.firstOfMonth {
                Button("dziś") {
                    month = today.firstOfMonth
                }
                .buttonStyle(LinkButtonStyle())
                .padding(.trailing, Spacing.hairline)
                .accessibilityLabel(Text("wróć do bieżącego miesiąca"))
            }
            ChevronStepButton(systemImage: "chevron.left", label: "poprzedni miesiąc") {
                month = month.addingMonths(-1)
            }
            ChevronStepButton(systemImage: "chevron.right", label: "następny miesiąc") {
                month = month.addingMonths(1)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: Spacing.hairline) {
            ForEach(0..<7, id: \.self) { index in
                Text(PolishDate.weekdayInitials[index])
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Spacing.hairline)
                    .accessibilityHidden(true)
            }
            ForEach(cells) { cell in
                if let date = cell.date {
                    DayCell(date: date,
                            info: engine.phase(on: date, today: today),
                            isMarked: periodDays.contains(date),
                            isToday: date == today,
                            isFuture: date > today,
                            hasSymptoms: symptomDays.contains(date),
                            symptomsTitle: SymptomsCard.title(on: date, today: today),
                            onShowSymptoms: { onShowSymptoms(date) },
                            opensFeelings: mode == .feelings) {
                        tap(date)
                    }
                } else {
                    Color.clear
                        .frame(height: TapSize.minimum)
                        .accessibilityHidden(true)
                }
            }
        }
        // The day numbers sit in fixed circles; beyond this size they would no longer fit.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// How the calendar works, on tap; in the "samopoczucie" mode one line about what to do.
    @ViewBuilder
    private var footer: some View {
        switch mode {
        case .period:
            MoreInfo("jak to działa?",
                     text: "dotknij dnia, żeby zaznaczyć albo odznaczyć okres. Gwiazdka pod dniem znaczy, że zapisałaś, jak się wtedy czułaś – otworzysz to, wybierając u góry „samopoczucie” albo przytrzymując dzień")
        case .feelings:
            Text(polish: "wybierz dzień, żeby zobaczyć albo zapisać, jak się wtedy czułaś")
                .hintText()
        }
    }

    // MARK: - Days

    private func tap(_ date: LocalDate) {
        switch mode {
        case .period:
            toggles += 1
            onToggle(date)
        case .feelings:
            onShowSymptoms(date)
        }
    }

    private var cells: [CalendarCell] {
        let first = month.firstOfMonth
        let leading = first.isoWeekday - 1
        let count = LocalDate.daysInMonth(year: first.year, month: first.month)
        let blanks = (0..<leading).map { CalendarCell(id: $0, date: nil) }
        let days = (0..<count).map { CalendarCell(id: leading + $0, date: first.adding(days: $0)) }
        return blanks + days
    }
}

/// Like `.plain`, but without the automatic dimming of disabled buttons: future days are
/// disabled, and their colours already say so – dimming them twice made them unreadable.
struct DayCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// One day of the month: its number in a 40 pt circle, and under it the phase dot and a star when
/// she noted how she felt. A tap marks or unmarks the period – or, with `opensFeelings`, opens how
/// she felt; a long press always offers the latter.
struct DayCell: View {
    let date: LocalDate
    let info: PhaseInfo?
    let isMarked: Bool
    let isToday: Bool
    let isFuture: Bool
    /// She noted how she felt that day: a small star under the number.
    let hasSymptoms: Bool
    /// The question of that day's form, for the long-press menu.
    let symptomsTitle: String
    let onShowSymptoms: () -> Void
    /// A tap opens how she felt instead of marking the period.
    var opensFeelings = false
    let action: () -> Void

    private static let circle: CGFloat = 40

    var body: some View {
        withSymptomsMenu(
            Button(action: action) {
                VStack(spacing: Spacing.hairline) {
                    Text(String(date.day))
                        .font(.body.weight(isMarked || isToday ? .semibold : .regular).monospacedDigit())
                        .foregroundStyle(numberColor)
                        .frame(width: Self.circle, height: Self.circle)
                        .background { marker }
                    HStack(spacing: Spacing.hairline) {
                        if let dotColor {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 5, height: 5)
                        }
                        if hasSymptoms {
                            OrganicStar()
                                .fill(opensFeelings ? Palette.accent : Palette.accentDim)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(DayCellButtonStyle())
            .disabled(isDisabled)
            .accessibilityLabel(Text(accessibilityText))
            .accessibilityHint(Text(opensFeelings ? "otwiera, jak się wtedy czułaś" : "zaznacza albo odznacza okres"))
            .accessibilityIdentifier("day-\(date.iso)")
        )
    }

    /// A long press on a day she has lived opens how she felt then. A tap still does its own thing.
    @ViewBuilder
    private func withSymptomsMenu<Cell: View>(_ cell: Cell) -> some View {
        if isFuture {
            cell
        } else {
            cell
                .accessibilityAction(named: Text(symptomsTitle), onShowSymptoms)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .contextMenu {
                    Button(action: onShowSymptoms) {
                        Label(symptomsTitle, systemImage: "sparkle")
                    }
                }
        }
    }

    /// A future day can't be marked or described, but one marked earlier can still be unmarked.
    private var isDisabled: Bool {
        opensFeelings ? isFuture : isFuture && !isMarked
    }

    /// An unmarked day inside a period she marked: it counts as part of that period.
    private var isBridged: Bool {
        guard let info, !isMarked else { return false }
        return info.phase == .menstrual && info.isLoggedPeriod
    }

    /// Her period filled, a bridged day softly filled, today ringed, a forecast dashed.
    @ViewBuilder private var marker: some View {
        if isMarked {
            Circle().fill(Palette.accent)
        } else if isBridged {
            Circle().fill(Palette.accent.opacity(0.3))
        } else if isToday {
            Circle().strokeBorder(Palette.accent.opacity(0.8), lineWidth: 1.5)
        } else if let info, info.phase == .menstrual {
            // A forecast: softer when it is only a rough guess.
            Circle()
                .strokeBorder(CyclePhase.menstrual.tint, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .opacity(info.confidence == .low ? 0.6 : 1)
        }
    }

    private var numberColor: Color {
        if isMarked { return Palette.onAccent }
        if isBridged { return Palette.text }
        if isFuture { return Palette.muted }
        return isToday ? Palette.text : Palette.text2
    }

    /// The phase dot; none on period days.
    private var dotColor: Color? {
        guard let info, !isMarked, info.phase != .menstrual else { return nil }
        return info.phase.tint.opacity(info.confidence == .low ? 0.4 : 0.9)
    }

    private var accessibilityText: String {
        var parts = [PolishDate.dayMonth(date)]
        if isMarked {
            parts.append("okres zaznaczony")
        } else if isBridged {
            parts.append("w środku zaznaczonego okresu")
        } else if let info {
            if info.phase == .menstrual {
                parts.append("prognoza okresu")
            } else {
                parts.append(info.isPrediction ? "prognoza: \(info.phase.label)" : info.phase.label)
            }
        }
        if hasSymptoms {
            parts.append("zapisane samopoczucie")
        }
        if isToday {
            parts.append("dziś")
        }
        return parts.joined(separator: ", ")
    }
}

/// What the marks in the month mean, in one short line: her period, the forecast and the phases
/// – or, while a tap opens how she felt, the star of the days she noted it. It wraps only at large
/// text sizes.
struct CalendarLegend: View {
    var mode = CalendarTapMode.period

    var body: some View {
        let flow = FlowLayout(spacing: Spacing.item, lineSpacing: Spacing.tight)
        flow {
            switch mode {
            case .period:
                LegendItem(label: "okres") {
                    Circle().fill(Palette.accent)
                }
                LegendItem(label: "prognoza") {
                    Circle().strokeBorder(CyclePhase.menstrual.tint, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                }
                ForEach([CyclePhase.follicular, .ovulatory, .luteal], id: \.self) { phase in
                    LegendItem(label: phase.season) {
                        Circle().fill(phase.tint)
                    }
                }
            case .feelings:
                LegendItem(label: "zapisane samopoczucie") {
                    OrganicStar().fill(Palette.accent)
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(Palette.muted)
    }
}

struct LegendItem<Swatch: View>: View {
    let label: String
    @ViewBuilder var swatch: Swatch

    var body: some View {
        HStack(spacing: Spacing.tight) {
            swatch
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            Text(label)
        }
    }
}
