import Foundation

/// A calendar day without a time or a time zone, e.g. 2026-11-07.
///
/// Day arithmetic goes through Julian Day Numbers, so results never shift at midnight,
/// across daylight saving changes or between time zones (the web version had such bugs).
public struct LocalDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Out-of-range values roll over: month 13 is January of the next year, 31 June is 1 July.
    public init(year: Int, month: Int, day: Int) {
        let monthIndex = month - 1
        let yearShift = monthIndex >= 0 ? monthIndex / 12 : -((11 - monthIndex) / 12)
        let normalizedMonth = monthIndex - yearShift * 12 + 1
        self.init(julianDay: LocalDate.julianDay(year: year + yearShift, month: normalizedMonth, day: day))
    }

    /// The date of a Julian Day Number (Fliegel–Van Flandern algorithm).
    public init(julianDay: Int) {
        let a = julianDay + 32_044
        let b = (4 * a + 3) / 146_097
        let c = a - 146_097 * b / 4
        let d = (4 * c + 3) / 1_461
        let e = c - 1_461 * d / 4
        let m = (5 * e + 2) / 153
        day = e - (153 * m + 2) / 5 + 1
        month = m + 3 - 12 * (m / 10)
        year = 100 * b + d - 4_800 + m / 10
    }

    public var julianDay: Int {
        LocalDate.julianDay(year: year, month: month, day: day)
    }

    /// Expects a month in 1...12; the day may overflow (it is simply added).
    static func julianDay(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4_800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32_045
    }

    /// ISO weekday: 1 = Monday … 7 = Sunday.
    public var isoWeekday: Int { julianDay % 7 + 1 }

    public func adding(days: Int) -> LocalDate {
        LocalDate(julianDay: julianDay + days)
    }

    /// Whole days from this date to `other`; positive when `other` is later.
    public func days(to other: LocalDate) -> Int {
        other.julianDay - julianDay
    }

    public var firstOfMonth: LocalDate {
        LocalDate(year: year, month: month, day: 1)
    }

    /// The same day in another month, clamped to that month's length (31 Jan + 1 month = 28 Feb).
    public func addingMonths(_ months: Int) -> LocalDate {
        let target = LocalDate(year: year, month: month + months, day: 1)
        let length = LocalDate.daysInMonth(year: target.year, month: target.month)
        return LocalDate(year: target.year, month: target.month, day: Swift.min(day, length))
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        let first = LocalDate(year: year, month: month, day: 1)
        return first.days(to: LocalDate(year: year, month: month + 1, day: 1))
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: - Text

    /// "2026-11-07"
    public var iso: String {
        let paddedMonth = month < 10 ? "0\(month)" : "\(month)"
        let paddedDay = day < 10 ? "0\(day)" : "\(day)"
        return "\(year)-\(paddedMonth)-\(paddedDay)"
    }

    /// Parses "2026-11-07"; anything after the first ten characters (like a time) is ignored.
    public init?(iso: String) {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month),
              day >= 1, day <= LocalDate.daysInMonth(year: year, month: month)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    // MARK: - System calendar

    public static func today(calendar: Calendar = .current, now: Date = Date()) -> LocalDate {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return LocalDate(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }
}

extension LocalDate: CustomStringConvertible {
    public var description: String { iso }
}

// Stored as "2026-11-07", also when used as a dictionary key.
extension LocalDate: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let date = LocalDate(iso: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(text)")
        }
        self = date
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }
}

extension LocalDate: CodingKeyRepresentable {
    public var codingKey: any CodingKey {
        DateCodingKey(stringValue: iso)
    }

    public init?<T: CodingKey>(codingKey: T) {
        guard let date = LocalDate(iso: codingKey.stringValue) else { return nil }
        self = date
    }
}

private struct DateCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}
