/// Groups marked bleeding days into periods.
public enum CycleMath {
    /// Unmarked days inside a period (up to `maxGapDays`) are bridged, so a light day she
    /// forgot to mark doesn't split one period into two.
    public static func periods(from days: some Collection<LocalDate>, maxGapDays: Int = 2) -> [PeriodRange] {
        var result: [PeriodRange] = []
        var start: LocalDate?
        var end: LocalDate?
        for day in Set(days).sorted() {
            if let currentStart = start, let currentEnd = end {
                if currentEnd.days(to: day) <= maxGapDays + 1 {
                    end = day
                } else {
                    result.append(PeriodRange(start: currentStart, end: currentEnd))
                    start = day
                    end = day
                }
            } else {
                start = day
                end = day
            }
        }
        if let start, let end {
            result.append(PeriodRange(start: start, end: end))
        }
        return result
    }
}

/// Works out the cycle day, the phase and the next period from the days she marked.
///
/// Built for irregular cycles. The luteal phase (ovulation → next period) is the steadier
/// half, so ovulation is counted back from the period. Wherever the history is too uneven
/// to tell, the result says so through `Confidence` instead of guessing with certainty.
public struct CycleEngine: Sendable {
    /// After this many days without a new period the history is treated as incomplete.
    public static let staleAfterDays = 90

    public let periods: [PeriodRange]
    public let stats: CycleStats
    /// Assumed days from ovulation to the next period (typically 12–14).
    public let lutealLength: Int

    public init(periodDays: some Collection<LocalDate>, lutealLength: Int = 13) {
        let periods = CycleMath.periods(from: periodDays)
        self.periods = periods
        self.stats = CycleStats(periods: periods)
        self.lutealLength = lutealLength
    }

    // MARK: - Today

    public func status(on today: LocalDate) -> CycleStatus {
        guard let current = periods.last(where: { $0.start <= today }) else {
            return CycleStatus(state: .noData, cycleDay: nil, lastPeriod: nil, prediction: nil)
        }
        let cycleDay = current.start.days(to: today) + 1
        if cycleDay > Self.staleAfterDays {
            return CycleStatus(state: .stale(daysSinceLastPeriod: cycleDay - 1),
                               cycleDay: cycleDay, lastPeriod: current, prediction: nil)
        }
        let prediction = nextPeriod(after: current)
        if today > prediction.latest {
            return CycleStatus(state: .late(daysLate: prediction.expected.days(to: today)),
                               cycleDay: cycleDay, lastPeriod: current, prediction: prediction)
        }
        let info = phase(on: today, today: today)
            ?? PhaseInfo(phase: .luteal, cycleDay: cycleDay, confidence: .low,
                         isLoggedPeriod: false, isPrediction: false)
        return CycleStatus(state: .active(info), cycleDay: cycleDay, lastPeriod: current, prediction: prediction)
    }

    /// The expected start of the period after `period`, with a window as wide as her recent spread.
    public func nextPeriod(after period: PeriodRange) -> PeriodPrediction {
        let typical = stats.typicalCycleLength
        var earliestOffset = typical - 3
        var latestOffset = typical + 3
        if stats.cycleLengths.count >= 2, let shortest = stats.shortestCycle, let longest = stats.longestCycle {
            earliestOffset = Swift.max(shortest, typical - 10)
            latestOffset = Swift.min(longest, typical + 10)
        }
        earliestOffset = Swift.min(earliestOffset, typical - 2)
        latestOffset = Swift.max(latestOffset, typical + 2)
        return PeriodPrediction(expected: period.start.adding(days: typical),
                                earliest: period.start.adding(days: earliestOffset),
                                latest: period.start.adding(days: latestOffset),
                                confidence: stats.confidence)
    }

    // MARK: - Any day

    /// The phase of `date`, or `nil` when the data can't tell (before the first period,
    /// after a long gap, or after the expected window of a late period).
    public func phase(on date: LocalDate, today: LocalDate) -> PhaseInfo? {
        guard let current = periods.last(where: { $0.start <= date }) else { return nil }
        let cycleDay = current.start.days(to: date) + 1
        let isPrediction = date > today

        if current.contains(date) {
            return PhaseInfo(phase: .menstrual, cycleDay: cycleDay, confidence: .high,
                             isLoggedPeriod: true, isPrediction: isPrediction)
        }

        // A finished cycle: the next start is known, so ovulation is counted back from it.
        if let next = periods.first(where: { $0.start > date }) {
            let length = current.start.days(to: next.start)
            guard CycleStats.plausibleCycleRange.contains(length) else { return nil }
            return PhaseInfo(phase: classify(cycleDay: cycleDay, ovulationDay: length - lutealLength),
                             cycleDay: cycleDay, confidence: .medium,
                             isLoggedPeriod: false, isPrediction: isPrediction)
        }

        // The cycle that is still running.
        guard cycleDay <= Self.staleAfterDays else { return nil }
        let prediction = nextPeriod(after: current)
        if today > prediction.latest {
            // Late: no guessing past the end of the expected window.
            guard date <= prediction.latest else { return nil }
        } else if isPrediction && date >= prediction.expected {
            let anchor = Swift.max(prediction.expected, today.adding(days: 1))
            return projectedPhase(on: date, cycleStart: anchor)
        }
        let (phase, confidence) = classifyRunningCycle(cycleDay: cycleDay)
        return PhaseInfo(phase: phase, cycleDay: cycleDay, confidence: confidence,
                         isLoggedPeriod: false, isPrediction: isPrediction)
    }

    // MARK: - Helpers

    private func classifyRunningCycle(cycleDay: Int) -> (CyclePhase, Confidence) {
        let typical = stats.typicalCycleLength
        let base = stats.confidence
        let earliestOvulation = (stats.shortestCycle ?? typical) - lutealLength
        let latestOvulation = (stats.longestCycle ?? typical) - lutealLength
        if cycleDay < earliestOvulation - 1 {
            return (.follicular, Swift.max(base, .medium))
        }
        if cycleDay > latestOvulation + 1 {
            return (.luteal, Swift.max(base, .medium))
        }
        // Between the earliest and the latest possible ovulation only the most likely phase is known.
        let confidence: Confidence = latestOvulation - earliestOvulation <= 3 ? base : .low
        return (classify(cycleDay: cycleDay, ovulationDay: typical - lutealLength), confidence)
    }

    private func projectedPhase(on date: LocalDate, cycleStart: LocalDate) -> PhaseInfo {
        let typical = stats.typicalCycleLength
        let offset = cycleStart.days(to: date)
        let dayInCycle = offset % typical + 1
        let confidence = stats.confidence.lowered(by: offset / typical)
        let phase: CyclePhase = dayInCycle <= stats.typicalPeriodLength
            ? .menstrual
            : classify(cycleDay: dayInCycle, ovulationDay: typical - lutealLength)
        return PhaseInfo(phase: phase, cycleDay: dayInCycle, confidence: confidence,
                         isLoggedPeriod: false, isPrediction: true)
    }

    private func classify(cycleDay: Int, ovulationDay: Int) -> CyclePhase {
        if cycleDay <= ovulationDay - 2 { return .follicular }
        if cycleDay <= ovulationDay + 1 { return .ovulatory }
        return .luteal
    }
}
