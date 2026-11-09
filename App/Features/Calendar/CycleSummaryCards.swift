import SwiftUI
import AboutHerCore

/// Typical cycle and period length, with an honest note when cycles vary a lot.
struct CycleStatsCard: View {
    let stats: CycleStats

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Twój rytm").sectionTitle()
                if stats.cycleLengths.isEmpty {
                    Text("zaznacz przynajmniej dwa okresy, a policzę Twój typowy cykl")
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
                        Text(irregularNote)
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

    private var irregularNote: String {
        let spread = stats.variability.map { "różnią się nawet o \(PolishPlural.days($0))" } ?? "bywają długie"
        return "Twoje cykle \(spread), więc prognozy są szerokie, a fazy w drugiej połowie cyklu to szacunek. "
            + "Jeśli cykle regularnie trwają dłużej niż 38 dni albo bardzo się różnią, warto wspomnieć o tym ginekologowi."
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
                .font(.ahDisplay(22, weight: .medium))
                .foregroundStyle(Palette.text)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Past periods, newest first, with the length of the cycle that followed each one.
struct PeriodHistoryCard: View {
    let periods: [PeriodRange]

    nonisolated struct Row: Identifiable {
        let period: PeriodRange
        let cycleLength: Int?
        var id: LocalDate { period.start }
    }

    var body: some View {
        let rows = makeRows()
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("historia okresów")
                    .sectionTitle()
                    .padding(.bottom, 6)
                if rows.isEmpty {
                    Text("tu pojawią się Twoje okresy, gdy zaznaczysz je w kalendarzu")
                        .bodyText()
                } else {
                    ForEach(rows) { row in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(CyclePhase.menstrual.tint)
                                .frame(width: 6, height: 6)
                            Text("\(PolishDate.range(row.period.start, row.period.end)) · \(PolishPlural.days(row.period.length))")
                                .font(.subheadline)
                                .foregroundStyle(Palette.text2)
                            Spacer()
                            if let length = row.cycleLength {
                                Text("cykl \(PolishPlural.days(length))")
                                    .font(.caption)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(.vertical, 10)
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
