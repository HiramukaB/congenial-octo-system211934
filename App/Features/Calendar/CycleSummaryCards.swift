import SwiftUI
import AboutHerCore

/// Typical cycle and period length, with an honest note when cycles vary a lot or are long.
struct CycleStatsCard: View {
    let stats: CycleStats
    /// How many periods are marked; with two or more but no countable cycle, the gaps are too long.
    let periodCount: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Twój rytm").sectionTitle()
                if stats.cycleLengths.isEmpty {
                    Text(polish: periodCount >= 2
                         ? "między zaznaczonymi okresami są zbyt długie przerwy. Zaznacz dwa kolejne okresy, a policzę Twój typowy cykl"
                         : "zaznacz przynajmniej dwa okresy, a policzę Twój typowy cykl")
                        .bodyText()
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        StatTile(label: "typowy cykl",
                                 value: PolishPlural.days(stats.typicalCycleLength),
                                 detail: cycleRange)
                        StatTile(label: "typowy okres",
                                 value: PolishPlural.days(stats.typicalPeriodLength),
                                 detail: nil)
                    }
                    if stats.isIrregular || (stats.longestCycle ?? 0) > 38 {
                        Text(polish: rhythmNote)
                            .font(.footnote)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var cycleRange: String? {
        guard let shortest = stats.shortestCycle, let longest = stats.longestCycle, shortest != longest else { return nil }
        return "ostatnio \(shortest)–\(longest) dni"
    }

    private var rhythmNote: String {
        if stats.isIrregular, let spread = stats.variability {
            return "Twoje ostatnie cykle różnią się nawet o \(PolishPlural.days(spread)), więc prognozy są szerokie, a fazy w drugiej połowie cyklu to szacunek. Jeśli tak jest często, warto wspomnieć o tym ginekologowi"
        }
        let longest = stats.longestCycle ?? stats.typicalCycleLength
        return "najdłuższy z Twoich ostatnich cykli trwał \(PolishPlural.days(longest)). Jeśli cykle często są dłuższe niż 38 dni, warto wspomnieć o tym ginekologowi"
    }
}

struct StatTile: View {
    let label: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.muted)
            Text(value)
                .displayFont(22, weight: .medium, relativeTo: .title2)
                .foregroundStyle(Palette.text)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Past periods, newest first, with the length of the cycle that followed each one.
struct PeriodHistoryCard: View {
    let periods: [PeriodRange]

    nonisolated struct Row: Identifiable {
        let period: PeriodRange
        let cycleLength: Int?
        var id: LocalDate { period.start }

        /// A start-to-start distance outside the plausible range is a gap in her notes, not a cycle.
        var cycleLabel: String? {
            guard let cycleLength else { return nil }
            return CycleStats.plausibleCycleRange.contains(cycleLength)
                ? "cykl \(PolishPlural.days(cycleLength))"
                : "przerwa w zapisach"
        }
    }

    var body: some View {
        let rows = makeRows()
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("historia okresów")
                    .sectionTitle()
                    .padding(.bottom, 6)
                if rows.isEmpty {
                    Text(polish: "tu pojawią się Twoje okresy, gdy zaznaczysz je w kalendarzu")
                        .bodyText()
                } else {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(CyclePhase.menstrual.tint)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                            Text("\(PolishDate.range(row.period.start, row.period.end)) · \(PolishPlural.days(row.period.length))")
                                .font(.subheadline)
                                .foregroundStyle(Palette.text2)
                            Spacer()
                            if let label = row.cycleLabel {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                        if row.id != rows.last?.id {
                            Rectangle()
                                .fill(Palette.line)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func makeRows() -> [Row] {
        var rows: [Row] = []
        for (index, period) in periods.enumerated() {
            let next = index + 1 < periods.count ? periods[index + 1] : nil
            rows.append(Row(period: period, cycleLength: next.map { period.start.days(to: $0.start) }))
        }
        return rows.reversed()
    }
}
