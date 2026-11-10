import SwiftUI
import AboutHerCore

/// "dziś": a calm home for the day. A greeting with her name and her intention, where she is in
/// her cycle, how she feels, the day in short and what may serve her in this phase. Earlier days
/// can be browsed; they speak in the past tense.
struct TodayView: View {
    @Environment(AppStore.self) var store
    /// 0 = today, -1 = yesterday … (only past days can be browsed).
    @State var dayOffset = 0
    @Binding var selectedTab: AppTab
    /// The day "jedzenie" shows: the day in short opens the day she is looking at here.
    @Binding var foodDayOffset: Int

    var body: some View {
        let engine = store.cycle
        let today = store.today
        let date = today.adding(days: dayOffset)
        let isToday = dayOffset == 0
        let info = engine.phase(on: date, today: today)
        let status = engine.status(on: today)

        Screen(tint: info?.phase.tint) {
            VStack(alignment: .leading, spacing: Spacing.item) {
                TodayGreetingHeader(date: date,
                                    today: today,
                                    name: store.preferredName,
                                    onPrevious: { dayOffset -= 1 },
                                    onNext: { dayOffset = min(0, dayOffset + 1) },
                                    onToday: { dayOffset = 0 })
                // Her sentence for the day, right under the greeting.
                TodayIntentionCard(day: date, style: .inline)
            }
            .padding(.bottom, Spacing.tight)
            if isToday {
                CycleStatusCard(status: status,
                                today: today,
                                stats: engine.stats,
                                onMarkToday: { store.togglePeriodDay(today) },
                                onOpenCalendar: { selectedTab = .calendar })
            } else {
                PastDayCycleCard(info: info, cycleDay: engine.cycleDay(on: date))
            }
            SymptomsCard(day: date)
            // Slot: owner F's card; it shows itself only when it has something to offer.
            HumorTodayCard(day: date)
            DaySummaryCard(eaten: store.data.eaten(on: date),
                           targets: store.targetsWithMovement(on: date),
                           glasses: store.data.water(on: date).total,
                           isToday: isToday,
                           onOpenFood: {
                               foodDayOffset = dayOffset
                               selectedTab = .food
                           })
            if isToday, let phase = guidePhase(info: info, status: status) {
                PhaseGuideCard(phase: phase)
            }
            QuoteLine()
        }
        .onChange(of: store.today) {
            // A new day began while she was browsing: start again from today.
            dayOffset = 0
        }
    }

    /// The guide shows only when today's phase is known – never on a late or stale cycle.
    private func guidePhase(info: PhaseInfo?, status: CycleStatus) -> CyclePhase? {
        guard let info else { return nil }
        if case .active = status.state {
            return info.phase
        }
        return nil
    }
}

/// The top of "dziś": a greeting with her name – or, on an earlier day, how long ago it was – the
/// date with the steps to the day before and after, and the way back to today.
private struct TodayGreetingHeader: View {
    let date: LocalDate
    let today: LocalDate
    let name: String?
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    /// Read in `body`, so the greeting follows the time of day whenever she comes back to the app.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let isToday = date == today
        let _ = scenePhase
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Text(title(isToday: isToday))
                .screenTitle()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .center, spacing: Spacing.tight) {
                Text(dateLine)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.tight)
                ChevronStepButton(systemImage: "chevron.left", label: "poprzedni dzień", action: onPrevious)
                ChevronStepButton(systemImage: "chevron.right", label: "następny dzień",
                                  isEnabled: !isToday, action: onNext)
            }
            if !isToday {
                Button("wróć do dziś", action: onToday)
                    .buttonStyle(LinkButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "dzień dobry, Ola" today; "wczoraj", "przedwczoraj", "5 dni temu" for the days before.
    private func title(isToday: Bool) -> String {
        guard isToday else {
            return DayHeading.pastDay(date, today: today) ?? PolishDate.dayMonth(date)
        }
        let hour = Calendar.current.component(.hour, from: Date.now)
        return DayHeading.greeting(hour: hour, name: name)
    }

    /// "wtorek, 10 listopada", with the year when it isn't this year.
    private var dateLine: String {
        let long = PolishDate.long(date)
        return date.year == today.year ? long : "\(long) \(date.year)"
    }
}
