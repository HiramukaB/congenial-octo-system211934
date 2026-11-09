/// Phases as the app talks about them. `menstrual` is the bleeding part of the follicular phase.
public enum CyclePhase: String, Sendable, Codable, CaseIterable {
    case menstrual, follicular, ovulatory, luteal
}

/// How sure the app is about an estimate. Irregular cycles mean low confidence in the second half.
public enum Confidence: Int, Sendable, Codable, Comparable {
    case low, medium, high

    public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func lowered(by steps: Int) -> Confidence {
        Confidence(rawValue: Swift.max(0, rawValue - steps)) ?? .low
    }
}

/// Consecutive bleeding days.
public struct PeriodRange: Hashable, Sendable {
    public let start: LocalDate
    public let end: LocalDate

    public init(start: LocalDate, end: LocalDate) {
        self.start = start
        self.end = end
    }

    public var length: Int { start.days(to: end) + 1 }

    public func contains(_ date: LocalDate) -> Bool {
        date >= start && date <= end
    }
}

/// The phase of one particular day.
public struct PhaseInfo: Sendable, Equatable {
    public let phase: CyclePhase
    /// 1 = the first day of bleeding.
    public let cycleDay: Int
    public let confidence: Confidence
    /// The day lies inside a period she marked herself – not an estimate.
    public let isLoggedPeriod: Bool
    /// The day is in the future.
    public let isPrediction: Bool
}

public struct PeriodPrediction: Sendable, Equatable {
    /// The most likely start, based on the median of recent cycles.
    public let expected: LocalDate
    public let earliest: LocalDate
    public let latest: LocalDate
    public let confidence: Confidence
}

/// What the "today" screen should say about the cycle.
public struct CycleStatus: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        /// No period has been marked yet.
        case noData
        case active(PhaseInfo)
        /// Past the expected window (needs at least one complete cycle) – the period is late,
        /// or she forgot to mark it. `daysLate` counts from the expected date.
        case late(daysLate: Int)
        /// So long since the last marked period that the history is clearly incomplete.
        case stale(daysSinceLastPeriod: Int)
    }

    public let state: State
    public let cycleDay: Int?
    public let lastPeriod: PeriodRange?
    public let prediction: PeriodPrediction?
}
