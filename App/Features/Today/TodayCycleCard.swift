import SwiftUI
import AboutHerCore

/// Where she is in her cycle today, at a glance: the day, the phase and one line about the next
/// period. Why it is an estimate, and the possible range, open on tap ("więcej").
struct CycleStatusCard: View {
    let status: CycleStatus
    let today: LocalDate
    let stats: CycleStats
    let onMarkToday: () -> Void
    let onOpenCalendar: () -> Void

    var body: some View {
        Card(style: .highlight) {
            switch status.state {
            case .noData:
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    SectionHeader("Twój cykl")
                    Text(polish: "zaznacz pierwszy okres, a pokażę Ci, gdzie jesteś w cyklu")
                        .bodyText()
                    StarActionButton("otwórz kalendarz", size: .regular, action: onOpenCalendar)
                }
            case .active(let info):
                ActiveCycleContent(info: info,
                                   prediction: status.prediction,
                                   today: today,
                                   stats: stats,
                                   onMarkToday: onMarkToday)
            case .late(let daysLate):
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    SectionHeader("okres się spóźnia")
                    if let day = status.cycleDay {
                        TodayCycleDayLine(day: day)
                    }
                    Text(polish: lateLine(daysLate: daysLate))
                        .bodyText()
                    StarActionButton("zaznacz okres w kalendarzu", size: .regular, action: onOpenCalendar)
                    MoreInfo(text: lateExplanation)
                }
            case .stale(let days):
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    SectionHeader("ostatni zapisany okres")
                    Text(verbatim: "\(PolishPlural.days(days)) temu")
                        .displayFont(36, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.text)
                    Text(polish: "zaznacz okresy, które były od tamtej pory, a znów pokażę Ci prognozy")
                        .bodyText()
                    StarActionButton("otwórz kalendarz", size: .regular, action: onOpenCalendar)
                    MoreInfo(text: "jeśli okresu naprawdę nie było tak długo, warto powiedzieć o tym ginekologowi")
                }
            }
        }
    }

    /// "spodziewałam się go około 5 lis, czyli 3 dni temu"
    private func lateLine(daysLate: Int) -> String {
        guard let prediction = status.prediction else {
            return "minęło więcej dni, niż się spodziewałam"
        }
        return "spodziewałam się go około \(PolishDate.short(prediction.expected)), czyli \(PolishPlural.days(daysLate)) temu"
    }

    private var lateExplanation: String {
        guard let longest = stats.longestCycle, let day = status.cycleDay else {
            return "może zapomniałaś zaznaczyć okres?"
        }
        if day > longest {
            return "najdłuższy z Twoich ostatnich cykli miał \(PolishPlural.days(longest)). Może zapomniałaś zaznaczyć okres?"
        }
        return "zdarzył Ci się już cykl \(PolishPlural.days(longest)), więc to może być po prostu dłuższy cykl. Może też zapomniałaś zaznaczyć okres?"
    }
}

/// The running cycle: the day and the phase, when the next period may come, and – during a
/// period she hasn't marked yet – the way to mark today.
struct ActiveCycleContent: View {
    let info: PhaseInfo
    let prediction: PeriodPrediction?
    let today: LocalDate
    let stats: CycleStats
    let onMarkToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            TodayCycleDayLine(day: info.cycleDay, phase: info.phase, isEstimate: info.isEstimate)
            Text(polish: nextPeriodLine)
                .bodyText()
            if info.phase == .menstrual && !info.isLoggedPeriod {
                StarActionButton("zaznacz dziś jako dzień okresu", size: .regular, action: onMarkToday)
            }
            MoreInfo(text: details)
        }
    }

    /// "następny okres około 25 lis · za 15 dni"
    private var nextPeriodLine: String {
        guard let prediction else {
            return "nie zgaduję jeszcze, kiedy przyjdzie okres"
        }
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

    /// Why it is an estimate, and the window the next period may come in.
    private var details: String {
        var sentences: [String] = []
        if let note = info.confidenceNote(stats: stats) {
            sentences.append(note)
        }
        if let prediction {
            sentences.append("możliwy zakres: \(PolishDate.range(prediction.earliest, prediction.latest))")
        } else {
            sentences.append("ten cykl trwa dłużej niż przeciętny, a nie znam jeszcze Twojego rytmu")
        }
        return Self.joined(sentences)
    }

    /// Sentences of the app's lowercase style joined into one text: each after the first starts
    /// with a capital letter.
    private static func joined(_ sentences: [String]) -> String {
        var text = ""
        for sentence in sentences {
            if text.isEmpty {
                text = sentence
            } else {
                let first = sentence.prefix(1).uppercased()
                let rest = String(sentence.dropFirst())
                text += ". " + first + rest
            }
        }
        return text
    }
}

/// An earlier day: its day of the cycle and phase, as far as they can be told.
struct PastDayCycleCard: View {
    let info: PhaseInfo?
    let cycleDay: Int?

    var body: some View {
        if let day = info?.cycleDay ?? cycleDay {
            Card(style: .highlight) {
                VStack(alignment: .leading, spacing: Spacing.item) {
                    TodayCycleDayLine(day: day, phase: info?.phase, isEstimate: info?.isEstimate ?? false)
                    if info == nil {
                        Text(polish: "fazy tego dnia nie umiem określić – okres się wtedy spóźniał")
                            .hintText()
                    }
                }
            }
        } else {
            Card(style: .quiet) {
                Text(polish: "dla tego dnia nie umiem określić fazy cyklu")
                    .bodyText()
            }
        }
    }
}

/// The big number of the cycle day with its label under it, and the phase beside it – or under
/// it, when large text leaves no room beside.
private struct TodayCycleDayLine: View {
    let day: Int
    var phase: CyclePhase? = nil
    var isEstimate = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.item) {
                number
                Spacer(minLength: Spacing.item)
                pill
            }
            VStack(alignment: .leading, spacing: Spacing.item) {
                number
                pill
            }
        }
    }

    private var number: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(day))
                .bigNumber()
                .contentTransition(.numericText(value: Double(day)))
            Text("dzień cyklu")
                .rowDetail()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "dzień cyklu \(day)"))
    }

    @ViewBuilder
    private var pill: some View {
        if let phase {
            PhasePill(phase: phase, isEstimate: isEstimate)
        }
    }
}
