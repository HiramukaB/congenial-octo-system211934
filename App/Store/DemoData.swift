import AboutHerCore

/// A fictional, fairly regular history for screenshots – never her real data.
enum DemoData {
    static func make(today: LocalDate) -> AppData {
        var days = Set<LocalDate>()
        for startOffset in [-109, -78, -47, -16] {
            let start = today.adding(days: startOffset)
            for day in 0..<5 {
                days.insert(start.adding(days: day))
            }
        }
        return AppData(periodDays: days)
    }
}
