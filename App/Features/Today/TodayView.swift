import SwiftUI
import AboutHerCore

/// "dziś": where she is in the cycle and what may serve her today.
struct TodayView: View {
    @Environment(AppStore.self) var store
    /// 0 = today, -1 = yesterday … (only past days can be browsed).
    @State var dayOffset = 0
    @Binding var selectedTab: AppTab

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
                CycleStatusCard(status: status, today: today, stats: engine.stats) {
                    selectedTab = .calendar
                }
            } else {
                PastDayCycleCard(info: info)
            }
            if let phase = guidePhase(info: info, status: status) {
                PhaseGuideCard(phase: phase)
            }
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
                        .font(.ahDisplay(24).italic())
                        .foregroundStyle(Palette.accent)
                    Text(PolishDate.long(date))
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                } else {
                    Text(PolishDate.long(date))
                        .font(.ahDisplay(19, weight: .medium))
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
    let onOpenCalendar: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                switch status.state {
                case .noData:
                    Text("Twój cykl").eyebrow()
                    Text("zaznacz pierwszy okres w kalendarzu, a pokażę Ci, gdzie jesteś w cyklu")
                        .bodyText()
                    Button("otwórz kalendarz", action: onOpenCalendar)
                        .buttonStyle(LinkButtonStyle())
                case .active(let info):
                    ActiveCycleContent(info: info, prediction: status.prediction, today: today)
                case .late(let daysLate):
                    Text("okres się spóźnia").eyebrow()
                    Text(lateTitle(daysLate))
                        .font(.ahDisplay(36))
                        .foregroundStyle(Palette.text)
                    Text(lateExplanation)
                        .bodyText()
                    Button("zaznacz okres w kalendarzu", action: onOpenCalendar)
                        .buttonStyle(LinkButtonStyle())
                case .stale(let days):
                    Text("ostatni zapisany okres").eyebrow()
                    Text("\(PolishPlural.days(days)) temu")
                        .font(.ahDisplay(36))
                        .foregroundStyle(Palette.text)
                    Text("zaznacz kolejne okresy w kalendarzu, a prognozy znów będą miały sens")
                        .bodyText()
                    Button("otwórz kalendarz", action: onOpenCalendar)
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func lateTitle(_ days: Int) -> String {
        "o \(PolishPlural.days(days))"
    }

    private var lateExplanation: String {
        if let longest = stats.longestCycle {
            return "najdłuższy z Twoich ostatnich cykli miał \(PolishPlural.days(longest)). Może zapomniałaś zaznaczyć okres?"
        }
        return "może zapomniałaś zaznaczyć okres?"
    }
}

struct ActiveCycleContent: View {
    let info: PhaseInfo
    let prediction: PeriodPrediction?
    let today: LocalDate

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("dzień cyklu").eyebrow()
            HStack(alignment: .firstTextBaseline) {
                Text(String(info.cycleDay))
                    .font(.ahDisplay(58))
                    .foregroundStyle(Palette.text)
                    .contentTransition(.numericText())
                Spacer()
                PhasePill(phase: info.phase, isEstimate: info.isEstimate)
            }
            if let note = info.confidenceNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let prediction {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nextPeriodText(prediction))
                        .bodyText()
                    Text("możliwy zakres: \(PolishDate.range(prediction.earliest, prediction.latest))")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private func nextPeriodText(_ prediction: PeriodPrediction) -> String {
        let days = today.days(to: prediction.expected)
        let when: String
        if days > 0 {
            when = "za \(PolishPlural.days(days))"
        } else if days == 0 {
            when = "możliwe, że dziś"
        } else {
            when = "spodziewany od \(PolishPlural.days(-days))"
        }
        return "następny okres około \(PolishDate.short(prediction.expected)) · \(when)"
    }
}

struct PastDayCycleCard: View {
    let info: PhaseInfo?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                if let info {
                    Text("dzień cyklu").eyebrow()
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(info.cycleDay))
                            .font(.ahDisplay(58))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        PhasePill(phase: info.phase, isEstimate: info.isEstimate)
                    }
                } else {
                    Text("dla tego dnia nie mam jeszcze danych o cyklu")
                        .bodyText()
                }
            }
        }
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
                    Text("\(phase.season) · co Ci posłuży")
                        .sectionTitle()
                }
                GuideRow(symbol: "bolt.heart", title: "energia", text: phase.energyHint)
                GuideRow(symbol: "fork.knife", title: "jedzenie", text: phase.foodHint)
                GuideRow(symbol: "figure.yoga", title: "ruch", text: phase.movementHint)
                GuideRow(symbol: "calendar", title: "plan dnia", text: phase.planningHint)
                Text("to wskazówki, nie zasady. Jeśli dziś czujesz inaczej, słuchaj siebie")
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
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.muted)
                Text(text)
                    .bodyText()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
