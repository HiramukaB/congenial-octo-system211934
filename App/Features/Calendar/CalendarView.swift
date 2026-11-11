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
            CalendarModeSwitch(mode: mode) { newMode in
                mode = newMode
            }
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

/// "okres · samopoczucie": what a tap on a day does, as one calm switch – a soft track with the
/// chosen half lit, 44 pt to tap. One of two, so it reads as a switch rather than as two buttons.
private struct CalendarModeSwitch: View {
    let mode: CalendarTapMode
    let onSelect: (CalendarTapMode) -> Void
    @Namespace private var selection
    @State private var changes = 0

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarTapMode.allCases, id: \.self) { option in
                segment(option)
            }
        }
        .padding(Spacing.hairline)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.04))
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        }
        .animation(.snappy(duration: 0.2), value: mode)
        .sensoryFeedback(.selection, trigger: changes)
    }

    private func segment(_ option: CalendarTapMode) -> some View {
        let isOn = option == mode
        return Button {
            guard !isOn else { return }
            changes += 1
            onSelect(option)
        } label: {
            HStack(spacing: Spacing.tight) {
                if isOn {
                    OrganicStar()
                        .fill(Palette.accent)
                        .frame(width: 11, height: 11)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
                Text(option.label)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Palette.text : Palette.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: TapSize.minimum)
            .background {
                if isOn {
                    Capsule()
                        .fill(Palette.accent.opacity(0.16))
                        .overlay {
                            Capsule()
                                .strokeBorder(Palette.accent.opacity(0.5), lineWidth: 1)
                        }
                        .matchedGeometryEffect(id: "chosen", in: selection)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(Text(option.hint))
    }
}

extension CalendarTapMode {
    /// What VoiceOver says the choice does.
    nonisolated var hint: String {
        switch self {
        case .period: "dotknięcie dnia zaznacza albo odznacza okres"
        case .feelings: "dotknięcie dnia otwiera, jak się wtedy czułaś"
        }
    }
}
