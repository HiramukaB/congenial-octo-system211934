import Foundation

/// Lengths of her recent cycles and periods.
///
/// Medians instead of averages: one unusually long cycle shouldn't drag every prediction along.
public struct CycleStats: Sendable, Equatable {
    /// Cycle lengths outside this range are treated as gaps in the data, not as real cycles.
    public static let plausibleCycleRange = 15...90
    /// Only the most recent cycles describe her current rhythm.
    public static let recentWindow = 6

    /// Lengths of complete cycles (one start to the next), oldest first.
    public let cycleLengths: [Int]
    /// Median of the recent cycles; 28 while there is no history yet.
    public let typicalCycleLength: Int
    /// Median of the recent periods; 5 while there is no history yet.
    public let typicalPeriodLength: Int
    public let shortestCycle: Int?
    public let longestCycle: Int?
    /// How many of her finished periods `typicalPeriodLength` is based on (0: the textbook 5 days).
    public let periodLengthSampleCount: Int

    /// `today` keeps a period that may still be going on out of her usual period length.
    public init(periods: [PeriodRange], today: LocalDate? = nil) {
        var lengths: [Int] = []
        for (previous, next) in zip(periods, periods.dropFirst()) {
            let length = previous.start.days(to: next.start)
            if CycleStats.plausibleCycleRange.contains(length) {
                lengths.append(length)
            }
        }
        let recent = Array(lengths.suffix(CycleStats.recentWindow))
        // A period that may still be in progress, and a mark of a single day, say nothing about
        // how long her periods usually last.
        let finished = periods.filter { period in
            today.map { period.start.days(to: $0) >= 12 } ?? true
        }
        let recentPeriods = finished.suffix(CycleStats.recentWindow)
            .map(\.length)
            .filter { (2...12).contains($0) }

        cycleLengths = lengths
        typicalCycleLength = CycleStats.median(recent) ?? 28
        typicalPeriodLength = CycleStats.median(recentPeriods) ?? 5
        periodLengthSampleCount = recentPeriods.count
        shortestCycle = recent.min()
        longestCycle = recent.max()
    }

    /// The spread between the shortest and the longest recent cycle.
    public var variability: Int? {
        guard cycleLengths.count >= 2, let shortest = shortestCycle, let longest = longestCycle else { return nil }
        return longest - shortest
    }

    /// FIGO (2018): a spread of 8 days or more between cycles counts as irregular.
    public var isIrregular: Bool {
        (variability ?? 0) >= 8
    }

    public var confidence: Confidence {
        let count = Swift.min(cycleLengths.count, CycleStats.recentWindow)
        guard count >= 2, let spread = variability else { return .low }
        if count >= 3 && spread <= 4 { return .high }
        if spread <= 7 { return .medium }
        return .low
    }

    static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 {
            return sorted[middle]
        }
        return Int((Double(sorted[middle - 1] + sorted[middle]) / 2).rounded())
    }
}
