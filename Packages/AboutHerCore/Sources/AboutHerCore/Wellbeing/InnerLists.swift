import Foundation

extension WeeklyReflection {
    /// The questions of the weekly reflection, one a week in turn.
    public static let questions: [String] = [
        "co w tym tygodniu dało Ci najwięcej energii?",
        "z czego jesteś dumna, choćby to było drobne?",
        "co było najtrudniejsze – i jak sobie z tym poradziłaś?",
        "czego chciałabyś sobie w przyszłym tygodniu życzyć?",
        "kiedy czułaś się w tym tygodniu najbardziej sobą?",
        "co możesz sobie w przyszłym tygodniu odpuścić?",
        "za co możesz dziś podziękować sobie samej?",
    ]

    /// The question of the week `day` falls in: the same all week, the next one from Monday on.
    public static func question(forWeekOf day: LocalDate) -> String {
        let count = questions.count
        guard count > 0 else { return "" }
        // A Monday's Julian Day Number is a multiple of 7, so this counts weeks.
        let week = day.startOfWeek.julianDay / 7
        return questions[((week % count) + count) % count]
    }
}

/// A reflection of an earlier week, for the list of past weeks. Not stored as such: her file keeps
/// the reflections by the Monday of their week.
public struct PastReflection: Sendable, Hashable, Identifiable {
    /// The Monday of the week.
    public let week: LocalDate
    public let reflection: WeeklyReflection

    public var id: LocalDate { week }

    public init(week: LocalDate, reflection: WeeklyReflection) {
        self.week = week
        self.reflection = reflection
    }
}

extension AppData {
    /// Her small wins, the newest day first; wins of one day with the last one written first.
    public var winsNewestFirst: [SmallWin] {
        AppData.newestFirst(wins, day: { $0.day })
    }

    /// Her progress photos, the newest day first; photos of one day with the last one added first.
    public var photosNewestFirst: [ProgressPhoto] {
        AppData.newestFirst(photos, day: { $0.day })
    }

    /// The letters she can read on `day`, the one that opened last first.
    public func openLetters(on day: LocalDate) -> [Letter] {
        AppData.newestFirst(letters.filter { $0.isOpen(on: day) }, day: { $0.opensOn })
    }

    /// The letters still sealed on `day`, the one that opens soonest first.
    public func sealedLetters(on day: LocalDate) -> [Letter] {
        letters.enumerated()
            .filter { !$0.element.isOpen(on: day) }
            .sorted { ($0.element.opensOn, $0.offset) < ($1.element.opensOn, $1.offset) }
            .map { $0.element }
    }

    /// Her reflections of the weeks before the week of `day`, the latest week first.
    public func pastReflections(before day: LocalDate) -> [PastReflection] {
        let monday = day.startOfWeek
        return reflections
            .filter { $0.key < monday }
            .sorted { $0.key > $1.key }
            .map { PastReflection(week: $0.key, reflection: $0.value) }
    }

    /// `items` with the newest day first; items of one day in reverse order, the last one first.
    private static func newestFirst<Item>(_ items: [Item], day: (Item) -> LocalDate) -> [Item] {
        items.enumerated()
            .sorted { (day($0.element), $0.offset) > (day($1.element), $1.offset) }
            .map { $0.element }
    }
}
