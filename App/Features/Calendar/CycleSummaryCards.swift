import SwiftUI
import AboutHerCore

/// Her typical cycle and period length; when her cycles vary a lot or are long, an honest note
/// on tap.
struct CycleStatsCard: View {
    let stats: CycleStats
    /// How many periods are marked; with two or more but no countable cycle, the gaps are too long.
    let periodCount: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("Twój rytm")
                if stats.cycleLengths.isEmpty {
                    Text(polish: periodCount >= 2
                         ? "między zaznaczonymi okresami są długie przerwy. Zaznacz dwa kolejne, a policzę Twój typowy cykl"
                         : "zaznacz przynajmniej dwa okresy, a policzę Twój typowy cykl")
                        .bodyText()
                } else {
                    HStack(alignment: .top, spacing: Spacing.item) {
                        StatTile(label: "typowy cykl",
                                 value: PolishPlural.days(stats.typicalCycleLength),
                                 detail: cycleRange)
                        // Shown once at least one whole period is known – not the textbook five days.
                        if stats.periodLengthSampleCount > 0 {
                            StatTile(label: "typowy okres",
                                     value: PolishPlural.days(stats.typicalPeriodLength),
                                     detail: nil)
                        }
                    }
                    if stats.isIrregular || (stats.longestCycle ?? 0) > 38 {
                        MoreInfo("o Twoich cyklach", text: rhythmNote)
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
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Text(label)
                .rowDetail()
            Text(value)
                .displayFont(26, weight: .medium, relativeTo: .title2)
                .foregroundStyle(Palette.text)
            if let detail {
                Text(detail)
                    .hintText()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Past periods, newest first, with the length of the cycle that followed each one. The last few
/// show; the rest on tap.
struct PeriodHistoryCard: View {
    let periods: [PeriodRange]
    @State private var showsAll = false

    /// How many periods show before "pokaż wszystkie".
    private static let recentCount = 6

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

        /// "21–25 paź · 5 dni"
        var title: String {
            "\(PolishDate.range(period.start, period.end)) · \(PolishPlural.days(period.length))"
        }
    }

    var body: some View {
        let rows = makeRows()
        let shown = showsAll ? rows : Array(rows.prefix(Self.recentCount))
        let moreLabel: String = showsAll ? "pokaż mniej" : "pokaż wszystkie (\(rows.count))"
        Card(style: .quiet) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("historia okresów")
                if rows.isEmpty {
                    Text(polish: "tu pojawią się Twoje okresy, gdy zaznaczysz je w kalendarzu")
                        .bodyText()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(shown) { row in
                            if row.id != shown.first?.id {
                                RowDivider()
                            }
                            ListRow(row.title) {
                                if let label = row.cycleLabel {
                                    Text(label)
                                        .rowDetail()
                                }
                            }
                        }
                    }
                    if rows.count > Self.recentCount {
                        Button(moreLabel) {
                            withAnimation(.smooth(duration: 0.25)) {
                                showsAll.toggle()
                            }
                        }
                        .buttonStyle(LinkButtonStyle())
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
