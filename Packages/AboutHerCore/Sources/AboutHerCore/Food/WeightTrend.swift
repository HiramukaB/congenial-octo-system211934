import Foundation

/// One weigh-in and the smoothed trend up to and including it.
public struct WeightPoint: Sendable, Hashable {
    public var day: LocalDate
    /// What the scale said.
    public var kg: Double
    /// The smoothed weight: what the chart line and the headline changes use.
    public var trend: Double

    public init(day: LocalDate, kg: Double, trend: Double) {
        self.day = day
        self.kg = kg
        self.trend = trend
    }
}

/// A weight line that looks past day-to-day swings of water and the cycle phase.
///
/// Time-aware exponential smoothing: each weigh-in pulls the trend towards itself by
/// 1 − 0.5^(days since the previous weigh-in / half-life). Whether she weighs weekly or with
/// gaps, a steady new weight moves the trend halfway there in one half-life (10 days by default).
/// Values are not checked here; the app only accepts 25…250 kg.
public enum WeightTrend {
    /// Her weigh-ins sorted by day, each with its trend. The first trend is the first weigh-in.
    /// A half-life of zero or less turns the smoothing off.
    public static func points(_ weights: [LocalDate: Double], halfLifeDays: Double = 10) -> [WeightPoint] {
        var result: [WeightPoint] = []
        result.reserveCapacity(weights.count)
        var previousDay: LocalDate?
        var trend = 0.0
        for (day, kg) in weights.sorted(by: { $0.key < $1.key }) {
            if let lastDay = previousDay {
                let gap = Double(lastDay.days(to: day))
                let pull: Double = halfLifeDays > 0 ? 1 - pow(0.5, gap / halfLifeDays) : 1
                trend += pull * (kg - trend)
            } else {
                trend = kg
            }
            result.append(WeightPoint(day: day, kg: kg, trend: trend))
            previousDay = day
        }
        return result
    }

    /// The trend of the last weigh-in on or before `day`; `nil` before the first one.
    /// `points` as returned by `points(_:halfLifeDays:)`.
    public static func trend(on day: LocalDate, in points: [WeightPoint]) -> Double? {
        points.last(where: { $0.day <= day })?.trend
    }

    /// How far the trend moved in the `days` days up to `day` (negative = down):
    /// `trend(on: day)` − `trend(on: day − days)`.
    ///
    /// `nil` when that number would not mean what it says:
    /// - no weigh-in falls after the start, `day − days`, up to `day` (after a break in weighing
    ///   there is no news, which is not "no change");
    /// - the last weigh-in on or before the start lies more than `startSlackDays` days before
    ///   it (the change would span far more than `days` days), or there is none at all.
    public static func change(in points: [WeightPoint], overDays days: Int, endingAt day: LocalDate) -> Double? {
        let start = day.adding(days: -days)
        guard let endPoint = points.last(where: { $0.day <= day }),
              let startPoint = points.last(where: { $0.day <= start }),
              endPoint.day > start,
              startPoint.day.days(to: start) <= startSlackDays
        else { return nil }
        return endPoint.trend - startPoint.trend
    }

    /// How long before the start of `change(in:overDays:endingAt:)` its first weigh-in may lie:
    /// a week, so weekly weigh-ins always qualify.
    public static let startSlackDays = 7

    /// The latest trend minus her very first weigh-in; `nil` with fewer than two weigh-ins.
    public static func changeSinceStart(in points: [WeightPoint]) -> Double? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        return last.trend - first.kg
    }
}
