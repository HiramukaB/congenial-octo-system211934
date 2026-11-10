import SwiftUI
import AboutHerCore

/// "kalendarz": tap a day to mark or unmark a period; phases appear as coloured dots. A long press
/// on a day opens how she felt that day, and a small star marks the days she noted it.
struct CalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var month = LocalDate.today().firstOfMonth
    /// The day whose "jak się czułaś" card is open in a sheet.
    @State private var symptomsDay: SymptomsSheetDay? = nil

    var body: some View {
        let engine = store.cycle
        let today = store.today

        Screen(tint: engine.phase(on: today, today: today)?.phase.tint) {
            Text("kalendarz").screenTitle()
            MonthCard(month: $month,
                      engine: engine,
                      periodDays: store.data.periodDays,
                      symptomDays: Set(store.data.symptoms.keys),
                      today: today,
                      onShowSymptoms: { symptomsDay = SymptomsSheetDay(day: $0) },
                      onToggle: { store.togglePeriodDay($0) })
            CycleStatsCard(stats: engine.stats, periodCount: engine.periods.count)
            PeriodHistoryCard(periods: engine.periods)
        }
        .onChange(of: store.today) { oldDay, newDay in
            // A new month began while the app stayed open: follow it, unless she is looking at another month.
            if month == oldDay.firstOfMonth {
                month = newDay.firstOfMonth
            }
        }
        .sheet(item: $symptomsDay) { request in
            SymptomsSheet(day: request.day)
        }
    }
}

nonisolated struct CalendarCell: Identifiable {
    let id: Int
    let date: LocalDate?
}

struct MonthCard: View {
    @Binding var month: LocalDate
    let engine: CycleEngine
    let periodDays: Set<LocalDate>
    /// The days she noted how she felt.
    let symptomDays: Set<LocalDate>
    let today: LocalDate
    @State var toggles = 0
    /// A long press on a day: how she felt that day.
    let onShowSymptoms: (LocalDate) -> Void
    let onToggle: (LocalDate) -> Void

    var body: some View {
        Card {
            VStack(spacing: 12) {
                HStack {
                    StarButton(label: "poprzedni miesiąc") {
                        month = month.addingMonths(-1)
                    }
                    Spacer()
                    Text(PolishDate.monthYear(month))
                        .displayFont(18, weight: .medium, relativeTo: .headline)
                        .foregroundStyle(Palette.text)
                    Spacer()
                    StarButton(label: "następny miesiąc") {
                        month = month.addingMonths(1)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        Text(PolishDate.weekdayInitials[index])
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity)
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
                                    onShowSymptoms: { onShowSymptoms(date) }) {
                                toggles += 1
                                onToggle(date)
                            }
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                // The day numbers sit in fixed circles; beyond this size they would no longer fit.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                CalendarLegend()
                Text(polish: "dotknij dnia, żeby zaznaczyć albo odznaczyć okres, a przytrzymaj go, żeby zapisać, jak się wtedy czułaś")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: toggles)
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

struct DayCell: View {
    let date: LocalDate
    let info: PhaseInfo?
    let isMarked: Bool
    let isToday: Bool
    let isFuture: Bool
    /// She noted how she felt that day: a small star under the number.
    let hasSymptoms: Bool
    /// The question of that day's card, for the long-press menu.
    let symptomsTitle: String
    let onShowSymptoms: () -> Void
    let action: () -> Void

    var body: some View {
        withSymptomsMenu(
            Button(action: action) {
                VStack(spacing: 3) {
                    Text(String(date.day))
                        .font(.subheadline.weight(isMarked ? .semibold : .regular))
                        .foregroundStyle(numberColor)
                        .frame(width: 34, height: 34)
                        .background { marker }
                    HStack(spacing: 3) {
                        if let dotColor {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 4, height: 4)
                        }
                        if hasSymptoms {
                            OrganicStar()
                                .fill(Palette.accentDim)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .frame(height: 7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(DayCellButtonStyle())
            // A future day can't be marked, but one that was marked earlier can still be removed.
            .disabled(isFuture && !isMarked)
            .accessibilityLabel(Text(accessibilityText))
            .accessibilityIdentifier("day-\(date.iso)")
        )
    }

    /// A long press on a day she has lived opens how she felt then. A tap still marks the period.
    @ViewBuilder
    private func withSymptomsMenu<Cell: View>(_ cell: Cell) -> some View {
        if isFuture {
            cell
        } else {
            cell
                .accessibilityAction(named: Text(symptomsTitle), onShowSymptoms)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contextMenu {
                    Button(action: onShowSymptoms) {
                        Label(symptomsTitle, systemImage: "sparkle")
                    }
                }
        }
    }

    /// An unmarked day inside a period she marked: it counts as part of that period.
    private var isBridged: Bool {
        guard let info, !isMarked else { return false }
        return info.phase == .menstrual && info.isLoggedPeriod
    }

    @ViewBuilder private var marker: some View {
        if isMarked {
            Circle().fill(Palette.accent)
        } else if isBridged {
            Circle().fill(Palette.accent.opacity(0.3))
        } else if let info, info.phase == .menstrual {
            // A forecast: softer when it is only a rough guess.
            Circle()
                .strokeBorder(CyclePhase.menstrual.tint, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .opacity(info.confidence == .low ? 0.6 : 1)
        } else if isToday {
            Circle().strokeBorder(Palette.accentDim, lineWidth: 1)
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

struct CalendarLegend: View {
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                LegendItem(label: "okres") {
                    Circle().fill(Palette.accent)
                }
                LegendItem(label: "prognoza okresu") {
                    Circle().strokeBorder(CyclePhase.menstrual.tint, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
            }
            HStack(spacing: 16) {
                ForEach([CyclePhase.follicular, .ovulatory, .luteal], id: \.self) { phase in
                    LegendItem(label: phase.label) {
                        Circle().fill(phase.tint)
                    }
                }
            }
            LegendItem(label: "samopoczucie") {
                OrganicStar().fill(Palette.accentDim)
            }
        }
        .font(.caption2)
        .foregroundStyle(Palette.muted)
        .frame(maxWidth: .infinity)
    }
}

struct LegendItem<Swatch: View>: View {
    let label: String
    @ViewBuilder var swatch: Swatch

    var body: some View {
        HStack(spacing: 5) {
            swatch.frame(width: 8, height: 8)
            Text(label)
        }
    }
}
