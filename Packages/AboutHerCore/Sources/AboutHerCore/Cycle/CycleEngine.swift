/// Groups marked bleeding days into stretches and picks the ones that start a cycle.
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

    /// The bleeding stretches that start a new cycle, oldest first.
    ///
    /// - Bleeding that begins less than 15 days after a cycle start belongs to that cycle
    ///   (the rest of a split period, or spotting). When a single marked day is followed by
    ///   real bleeding within those days, the cycle starts with the bleeding instead.
    /// - Once she has marked at least two whole periods, a single marked day that comes too
    ///   early for a new cycle is read as spotting. While it may still be day one of a period
    ///   (marked today or yesterday) it does count as a start, so the app reacts right away.
    public static func cycleStarts(from stretches: [PeriodRange], today: LocalDate? = nil) -> [PeriodRange] {
        let minimumCycle = CycleStats.plausibleCycleRange.lowerBound
        let wholePeriods = stretches.filter { $0.length > 1 }
        let marksWholePeriods = wholePeriods.count >= 2
        let shortestCycle = CycleStats(periods: wholePeriods).shortestCycle ?? 21
        let earliestNewCycle = Swift.max(minimumCycle, shortestCycle - 3)

        var starts: [PeriodRange] = []
        for stretch in stretches {
            guard let previous = starts.last else {
                starts.append(stretch)
                continue
            }
            let gap = previous.start.days(to: stretch.start)
            if gap < minimumCycle {
                if previous.length == 1 && stretch.length > 1 {
                    starts[starts.count - 1] = stretch
                }
                continue
            }
            let mayStillBleed = today.map { stretch.end.days(to: $0) <= 1 } ?? false
            if marksWholePeriods && stretch.length == 1 && gap < earliestNewCycle && !mayStillBleed {
                continue
            }
            starts.append(stretch)
        }
        return starts
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

    /// The bleeding stretch that started each cycle, oldest first.
    public let periods: [PeriodRange]
    /// Every stretch of marked (or bridged) bleeding days, spotting included.
    public let bleeding: [PeriodRange]
    public let stats: CycleStats
    /// Assumed days from ovulation to the next period (typically 12–14).
    public let lutealLength: Int

    /// `today` lets a single day marked today or yesterday count as a possible first day of a period.
    public init(periodDays: some Collection<LocalDate>, today: LocalDate? = nil, lutealLength: Int = 13) {
        let stretches = CycleMath.periods(from: periodDays)
        let starts = CycleMath.cycleStarts(from: stretches, today: today)
        self.bleeding = stretches
        self.periods = starts
        self.stats = CycleStats(periods: starts)
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
        let isPastWindow = today > prediction.latest
        // "Late" needs at least one complete cycle; before that the window is only a textbook guess.
        if isPastWindow && !stats.cycleLengths.isEmpty {
            return CycleStatus(state: .late(daysLate: prediction.expected.days(to: today)),
                               cycleDay: cycleDay, lastPeriod: current, prediction: prediction)
        }
        let info = phase(on: today, today: today)
            ?? PhaseInfo(phase: .luteal, cycleDay: cycleDay, confidence: .low,
                         isLoggedPeriod: false, isPrediction: false)
        return CycleStatus(state: .active(info), cycleDay: cycleDay, lastPeriod: current,
                           prediction: isPastWindow ? nil : prediction)
    }

    /// The expected start of the period after `period`, with a window as wide as her recent spread.
    public func nextPeriod(after period: PeriodRange) -> PeriodPrediction {
        let typical = stats.typicalCycleLength
        var earliestOffset: Int
        var latestOffset: Int
        if stats.cycleLengths.count >= 2, let shortest = stats.shortestCycle, let longest = stats.longestCycle {
            earliestOffset = Swift.max(shortest, typical - 10)
            latestOffset = Swift.min(longest, typical + 10)
        } else {
            // Fewer than two cycles say little about her rhythm, so the window stays wide.
            earliestOffset = typical - 7
            latestOffset = typical + 7
        }
        earliestOffset = Swift.min(earliestOffset, typical - 2)
        latestOffset = Swift.max(latestOffset, typical + 2)
        return PeriodPrediction(expected: period.start.adding(days: typical),
                                earliest: period.start.adding(days: earliestOffset),
                                latest: period.start.adding(days: latestOffset),
                                confidence: stats.confidence)
    }

    // MARK: - Any day

    /// The day of the cycle that `date` falls in, or `nil` before the first period,
    /// inside a gap in the data and after a long time without a period.
    public func cycleDay(on date: LocalDate) -> Int? {
        guard let current = periods.last(where: { $0.start <= date }) else { return nil }
        let day = current.start.days(to: date) + 1
        if let next = periods.first(where: { $0.start > date }) {
            guard CycleStats.plausibleCycleRange.contains(current.start.days(to: next.start)) else { return nil }
        } else if day > Self.staleAfterDays {
            return nil
        }
        return day
    }

    /// The phase of `date`, or `nil` when the data can't tell (before the first period,
    /// after a long gap, or after the expected window of a late period).
    public func phase(on date: LocalDate, today: LocalDate) -> PhaseInfo? {
        guard let current = periods.last(where: { $0.start <= date }) else { return nil }
        let cycleDay = current.start.days(to: date) + 1
        let isPrediction = date > today

        if bleeding.contains(where: { $0.contains(date) }) {
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

        // Today or later, within her usual period length: most likely still bleeding, just not marked yet.
        if date >= today, cycleDay <= stats.typicalPeriodLength {
            return PhaseInfo(phase: .menstrual, cycleDay: cycleDay, confidence: .medium,
                             isLoggedPeriod: false, isPrediction: isPrediction)
        }

        let prediction = nextPeriod(after: current)
        if today > prediction.latest {
            // Past the window there is no guessing ahead: with a known rhythm the period is late,
            // and without one (first cycle) nothing after today can be told.
            let lastKnownDay = stats.cycleLengths.isEmpty ? today : prediction.latest
            guard date <= lastKnownDay else { return nil }
        } else if isPrediction && date >= prediction.expected {
            let anchor = Swift.max(prediction.expected, today.adding(days: 1))
            return projectedPhase(on: date, cycleStart: anchor,
                                  extraUncertainty: anchor > prediction.expected ? 1 : 0)
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

    /// Phases of future cycles. A forecast that already had to move (the expected day passed)
    /// is one step less certain.
    private func projectedPhase(on date: LocalDate, cycleStart: LocalDate, extraUncertainty: Int) -> PhaseInfo {
        let typical = stats.typicalCycleLength
        let offset = cycleStart.days(to: date)
        let dayInCycle = offset % typical + 1
        let confidence = stats.confidence.lowered(by: offset / typical + extraUncertainty)
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
