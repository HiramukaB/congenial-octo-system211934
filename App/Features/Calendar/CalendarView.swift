import SwiftUI
import AboutHerCore

/// What a tap on a day does in the calendar: mark the period, or open how she felt that day.
nonisolated enum CalendarTapMode: CaseIterable {
    case period
    case feelings

    var label: String {
        switch self {
        case .period: "okres"
        case .feelings: "samopoczucie"
        }
    }
}

/// "kalendarz": a tap on a day marks or unmarks a period; the phases show as coloured dots. With
/// "samopoczucie" chosen above the month, a tap opens how she felt that day instead (a long press
/// does that in both modes), and a small star marks the days she noted it.
struct CalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var month = LocalDate.today().firstOfMonth
    /// The day whose "jak się czułaś" form is open in a sheet.
    @State private var symptomsDay: SymptomsSheetDay? = nil
    /// What a tap on a day does; back to marking the period whenever she leaves the tab.
    @State private var mode = CalendarTapMode.period

    var body: some View {
        let engine = store.cycle
        let today = store.today

        Screen(tint: engine.phase(on: today, today: today)?.phase.tint) {
            ScreenHeader(title: "kalendarz")
            ChoiceTiles(options: CalendarTapMode.allCases,
                        selection: mode,
                        columns: 2,
                        label: { $0.label },
                        onSelect: { mode = $0 })
            MonthCard(month: $month,
                      engine: engine,
                      periodDays: store.data.periodDays,
                      symptomDays: Set(store.data.symptoms.keys),
                      today: today,
                      onShowSymptoms: { symptomsDay = SymptomsSheetDay(day: $0) },
                      mode: mode,
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
        .onDisappear {
            mode = .period
        }
        .sheet(item: $symptomsDay) { request in
            SymptomsSheet(day: request.day)
        }
    }
}
