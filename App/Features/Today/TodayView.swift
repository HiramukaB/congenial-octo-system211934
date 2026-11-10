import SwiftUI
import AboutHerCore

/// "dziś": where she is in the cycle and what may serve her today.
struct TodayView: View {
    @Environment(AppStore.self) var store
    /// 0 = today, -1 = yesterday … (only past days can be browsed).
    @State var dayOffset = 0
    @Binding var selectedTab: AppTab
    /// The day "jedzenie" shows: "otwórz jedzenie" opens the day she is looking at here.
    @Binding var foodDayOffset: Int

    var body: some View {
        let engine = store.cycle
        let today = store.today
        let date = today.adding(days: dayOffset)
        let info = engine.phase(on: date, today: today)
        let status = engine.status(on: today)

        Screen(tint: info?.phase.tint) {
            QuoteLine()
            DaySwitcher(date: date,
                        isToday: dayOffset == 0,
                        onPrevious: { dayOffset -= 1 },
                        onNext: { dayOffset = min(0, dayOffset + 1) },
                        onToday: { dayOffset = 0 })
            if dayOffset == 0 {
                CycleStatusCard(status: status,
                                today: today,
                                stats: engine.stats,
                                onMarkToday: { store.togglePeriodDay(today) },
                                onOpenCalendar: { selectedTab = .calendar })
            } else {
                PastDayCycleCard(info: info, cycleDay: engine.cycleDay(on: date))
            }
            TodayIntentionCard(day: date)
            DaySummaryCard(eaten: store.data.eaten(on: date),
                           targets: store.targets,
                           glasses: store.data.water(on: date).total,
                           onOpenFood: {
                               foodDayOffset = dayOffset
                               selectedTab = .food
                           })
            SymptomsCard(day: date)
            if let phase = guidePhase(info: info, status: status) {
                PhaseGuideCard(phase: phase)
            }
        }
        .onChange(of: store.today) {
            // A new day began while she was browsing: start again from today.
            dayOffset = 0
        }
    }

    /// The guide shows only when the phase is known – never on a late or stale cycle.
    private func guidePhase(info: PhaseInfo?, status: CycleStatus) -> CyclePhase? {
        guard let info else { return nil }
        guard dayOffset == 0 else { return info.phase }
        if case .active = status.state {
            return info.phase
        }
        return nil
    }
}

/// The motto from the web version: small, italic, always on one line.
struct QuoteLine: View {
    var body: some View {
        Text("od wielkiego marzenia dzielą Cię małe codzienne decyzje")
            .font(.ahDisplay(13).italic())
            .foregroundStyle(Palette.accentDim)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Stars on both sides switch days; "dziś" in italic serif in the middle.
struct DaySwitcher: View {
    let date: LocalDate
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            StarButton(label: "poprzedni dzień", action: onPrevious)
            VStack(spacing: 3) {
                if isToday {
                    Text("dziś")
                        .displayFont(24, italic: true, relativeTo: .title2)
                        .foregroundStyle(Palette.accent)
                    Text(PolishDate.long(date))
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                } else {
                    Text(PolishDate.long(date))
                        .displayFont(19, weight: .medium, relativeTo: .title3)
                        .foregroundStyle(Palette.text)
                    Button("wróć do dziś", action: onToday)
                        .buttonStyle(LinkButtonStyle(font: .caption.weight(.medium)))
                }
            }
            .frame(maxWidth: .infinity)
            StarButton(label: "następny dzień", isEnabled: !isToday, action: onNext)
        }
    }
}

struct CycleStatusCard: View {
    let status: CycleStatus
    let today: LocalDate
    let stats: CycleStats
    let onMarkToday: () -> Void
    let onOpenCalendar: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                switch status.state {
                case .noData:
                    Text("Twój cykl").eyebrow()
                    Text(polish: "zaznacz pierwszy okres w kalendarzu, a pokażę Ci, gdzie jesteś w cyklu")
                        .bodyText()
                    Button("otwórz kalendarz", action: onOpenCalendar)
                        .buttonStyle(LinkButtonStyle())
                case .active(let info):
                    ActiveCycleContent(info: info,
                                       prediction: status.prediction,
                                       today: today,
                                       stats: stats,
                                       onMarkToday: onMarkToday)
                case .late(let daysLate):
                    Text("okres się spóźnia").eyebrow()
                    Text("dzień cyklu \(status.cycleDay ?? 0)")
                        .displayFont(36, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.text)
                    Text(polish: lateText(daysLate: daysLate))
                        .bodyText()
                    Button("zaznacz okres w kalendarzu", action: onOpenCalendar)
                        .buttonStyle(LinkButtonStyle())
                case .stale(let days):
                    Text("ostatni zapisany okres").eyebrow()
                    Text("\(PolishPlural.days(days)) temu")
                        .displayFont(36, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.text)
                    Text(polish: "zaznacz w kalendarzu okresy, które były od tamtej pory, a znów pokażę Ci prognozy. Jeśli okresu naprawdę nie było tak długo, warto powiedzieć o tym ginekologowi")
                        .bodyText()
                    Button("otwórz kalendarz", action: onOpenCalendar)
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func lateText(daysLate: Int) -> String {
        guard let prediction = status.prediction else { return lateExplanation }
        return "spodziewałam się go około \(PolishDate.short(prediction.expected)), czyli \(PolishPlural.days(daysLate)) temu. "
            + lateExplanation
    }

    private var lateExplanation: String {
        guard let longest = stats.longestCycle, let day = status.cycleDay else {
            return "Może zapomniałaś zaznaczyć okres?"
        }
        if day > longest {
            return "Najdłuższy z Twoich ostatnich cykli miał \(PolishPlural.days(longest)). Może zapomniałaś zaznaczyć okres?"
        }
        return "Zdarzył Ci się już cykl \(PolishPlural.days(longest)), więc to może być po prostu dłuższy cykl. Może też zapomniałaś zaznaczyć okres?"
    }
}

struct ActiveCycleContent: View {
    let info: PhaseInfo
    let prediction: PeriodPrediction?
    let today: LocalDate
    let stats: CycleStats
    let onMarkToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("dzień cyklu").eyebrow()
            HStack(alignment: .firstTextBaseline) {
                Text(String(info.cycleDay))
                    .displayFont(58, relativeTo: .largeTitle)
                    .foregroundStyle(Palette.text)
                    .contentTransition(.numericText())
                Spacer()
                PhasePill(phase: info.phase, isEstimate: info.isEstimate)
            }
            if let note = info.confidenceNote(stats: stats) {
                Text(polish: note)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if info.phase == .menstrual && !info.isLoggedPeriod {
                Button("zaznacz dziś jako dzień okresu", action: onMarkToday)
                    .buttonStyle(LinkButtonStyle())
            }
            if let prediction {
                VStack(alignment: .leading, spacing: 2) {
                    Text(polish: nextPeriodText(prediction))
                        .bodyText()
                    Text("możliwy zakres: \(PolishDate.range(prediction.earliest, prediction.latest))")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            } else {
                Text(polish: "ten cykl trwa dłużej niż przeciętny, a nie znam jeszcze Twojego rytmu, więc nie zgaduję, kiedy przyjdzie okres")
                    .bodyText()
            }
        }
    }

    private func nextPeriodText(_ prediction: PeriodPrediction) -> String {
        let days = today.days(to: prediction.expected)
        let when: String
        switch days {
        case 2...:
            when = "za \(PolishPlural.days(days))"
        case 1:
            when = "możliwe, że jutro"
        case 0:
            when = "możliwe, że dziś"
        case -1:
            when = "spodziewany od wczoraj"
        default:
            when = "spodziewany od \(PolishPlural.days(-days))"
        }
        return "następny okres około \(PolishDate.short(prediction.expected)) · \(when)"
    }
}

struct PastDayCycleCard: View {
    let info: PhaseInfo?
    let cycleDay: Int?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                if let day = info?.cycleDay ?? cycleDay {
                    Text("dzień cyklu").eyebrow()
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(day))
                            .displayFont(58, relativeTo: .largeTitle)
                            .foregroundStyle(Palette.text)
                        Spacer()
                        if let info {
                            PhasePill(phase: info.phase, isEstimate: info.isEstimate)
                        }
                    }
                    if info == nil {
                        Text(polish: "fazy tego dnia nie umiem określić – okres się wtedy spóźniał")
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(polish: "dla tego dnia nie umiem określić fazy cyklu")
                        .bodyText()
                }
            }
        }
    }
}

/// "dzień w skrócie": calories and water at a glance, without opening the food tab.
struct DaySummaryCard: View {
    let eaten: Macros
    let targets: Macros?
    let glasses: Int
    let onOpenFood: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("dzień w skrócie").sectionTitle()
                summaryRow("kalorie", value: kcalText(joinedBy: " / "), spoken: kcalText(joinedBy: " z "))
                summaryRow("woda",
                           value: "\(glasses) / \(WaterDay.goalGlasses) szklanek",
                           spoken: "\(glasses) z \(WaterDay.goalGlasses) szklanek")
                Button("otwórz jedzenie", action: onOpenFood)
                    .buttonStyle(LinkButtonStyle())
            }
        }
    }

    /// "1240 / 1800 kcal" on screen; VoiceOver hears "1240 z 1800 kcal" instead of a slash.
    private func kcalText(joinedBy separator: String) -> String {
        let eatenKcal = FoodFormat.whole(eaten.kcal)
        guard let targets else { return "\(eatenKcal) kcal" }
        return "\(eatenKcal)\(separator)\(FoodFormat.whole(targets.kcal)) kcal"
    }

    private func summaryRow(_ label: String, value: String, spoken: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Palette.text2)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Palette.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(label): \(spoken)"))
    }
}

/// Energy, food, movement and planning hints for the phase – suggestions, never rules.
struct PhaseGuideCard: View {
    let phase: CyclePhase

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    OrganicStar()
                        .fill(phase.tint)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    Text("\(phase.season) · co Ci posłuży")
                        .sectionTitle()
                }
                GuideRow(symbol: phase.energySymbol, title: "energia", text: phase.energyHint)
                GuideRow(symbol: "fork.knife", title: "jedzenie", text: phase.foodHint)
                GuideRow(symbol: "figure.yoga", title: "ruch", text: phase.movementHint)
                GuideRow(symbol: "calendar", title: "plan dnia", text: phase.planningHint)
                Text(polish: "to wskazówki, nie zasady. Jeśli dziś czujesz inaczej, słuchaj siebie")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct GuideRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Palette.accentDim)
                .frame(width: 22)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.muted)
                Text(polish: text)
                    .bodyText()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
