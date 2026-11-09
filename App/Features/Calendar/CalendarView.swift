import SwiftUI
import AboutHerCore

/// "kalendarz": tap a day to mark or unmark a period; phases appear as coloured dots.
struct CalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var month = LocalDate.today().firstOfMonth

    var body: some View {
        let engine = store.cycle
        let today = store.today

        Screen(tint: engine.phase(on: today, today: today)?.phase.tint) {
            Text("kalendarz").screenTitle()
            MonthCard(month: $month, engine: engine, periodDays: store.data.periodDays, today: today) { date in
                store.togglePeriodDay(date)
            }
            CycleStatsCard(stats: engine.stats)
            PeriodHistoryCard(periods: engine.periods)
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
    let today: LocalDate
    @State var toggles = 0
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
                        .font(.ahDisplay(18, weight: .medium))
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
                    }
                    ForEach(cells) { cell in
                        if let date = cell.date {
                            DayCell(date: date,
                                    info: engine.phase(on: date, today: today),
                                    isMarked: periodDays.contains(date),
                                    isToday: date == today,
                                    isFuture: date > today) {
                                toggles += 1
                                onToggle(date)
                            }
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                CalendarLegend()
                Text("dotknij dnia, żeby zaznaczyć albo odznaczyć okres")
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

struct DayCell: View {
    let date: LocalDate
    let info: PhaseInfo?
    let isMarked: Bool
    let isToday: Bool
    let isFuture: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(String(date.day))
                    .font(.subheadline.weight(isMarked ? .semibold : .regular))
                    .foregroundStyle(numberColor)
                    .frame(width: 34, height: 34)
                    .background { marker }
                Circle()
                    .fill(dotColor)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(accessibilityText))
    }

    @ViewBuilder private var marker: some View {
        if isMarked {
            Circle().fill(Palette.accent)
        } else if let info, info.phase == .menstrual {
            // Predicted, or a day bridged inside a marked period.
            Circle().strokeBorder(CyclePhase.menstrual.tint, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
        } else if isToday {
            Circle().strokeBorder(Palette.accentDim, lineWidth: 1)
        }
    }

    private var numberColor: Color {
        if isMarked { return Palette.onAccent }
        if isFuture { return Palette.muted }
        return isToday ? Palette.text : Palette.text2
    }

    private var dotColor: Color {
        guard let info, !isMarked, info.phase != .menstrual else { return .clear }
        return info.phase.tint.opacity(info.confidence == .low ? 0.4 : 0.9)
    }

    private var accessibilityText: String {
        var parts = [PolishDate.dayMonth(date)]
        if isMarked {
            parts.append("okres zaznaczony")
        } else if let info {
            parts.append(info.isPrediction ? "prognoza: \(info.phase.label)" : info.phase.label)
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
