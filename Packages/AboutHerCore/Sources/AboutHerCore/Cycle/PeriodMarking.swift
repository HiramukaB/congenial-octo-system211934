/// Marking a whole period in one go, as in the welcome: "it started on the 3rd and lasts about
/// five days".
extension AppData {
    /// The most days one answer marks.
    public static let longestMarkedPeriod = 14

    /// Marks a period the way the calendar marks it, day by day: `count` days from `start` – at most
    /// `longestMarkedPeriod` – and never a day after `today`. First it takes back `earlier`, the
    /// days an earlier answer marked, so a corrected answer leaves nothing behind. Days that were
    /// marked before stay marked.
    ///
    /// Returns the days it marked that weren't marked yet: what the next correction takes back.
    /// With `start` nil, a `start` after `today` or a `count` below 1 it only takes back `earlier`.
    @discardableResult
    public mutating func markPeriodDays(from start: LocalDate?, count: Int, today: LocalDate,
                                        replacing earlier: Set<LocalDate> = []) -> Set<LocalDate> {
        periodDays.subtract(earlier)
        guard let start, start <= today, count >= 1 else { return [] }
        let length = Swift.min(count, AppData.longestMarkedPeriod)
        let last = Swift.min(start.adding(days: length - 1), today)
        var added: Set<LocalDate> = []
        var day = start
        while day <= last {
            if periodDays.insert(day).inserted {
                added.insert(day)
            }
            day = day.adding(days: 1)
        }
        return added
    }
}
