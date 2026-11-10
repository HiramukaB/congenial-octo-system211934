import Foundation

/// A small win she wrote down, on the day it belongs to.
public struct SmallWin: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var day: LocalDate
    public var text: String

    public init(id: UUID = UUID(), day: LocalDate, text: String) {
        self.id = id
        self.day = day
        self.text = text
    }
}

/// Her answer to the question of one week.
public struct WeeklyReflection: Codable, Sendable, Hashable {
    /// The question as she saw it, so the answer keeps its meaning when the questions change.
    public var question: String
    public var answer: String

    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

/// A letter to herself, sealed until the day she chose.
public struct Letter: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var writtenOn: LocalDate
    public var opensOn: LocalDate
    public var text: String

    public init(id: UUID = UUID(), writtenOn: LocalDate, opensOn: LocalDate, text: String) {
        self.id = id
        self.writtenOn = writtenOn
        self.opensOn = opensOn
        self.text = text
    }

    /// Whether she can read it on `day`.
    public func isOpen(on day: LocalDate) -> Bool {
        day >= opensOn
    }

    /// When a letter written on `day` opens unless she picks another day: three months later.
    public static func defaultOpeningDay(writtenOn day: LocalDate) -> LocalDate {
        day.addingMonths(3)
    }
}

/// A progress photo. The image is a JPEG in the app's own photos folder, named `fileName` –
/// never inside her data file and never in her photo library.
public struct ProgressPhoto: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    /// The day the photo belongs to.
    public var day: LocalDate

    public init(id: UUID = UUID(), day: LocalDate) {
        self.id = id
        self.day = day
    }

    /// The JPEG's name in the photos folder. Made only from the id, so it can't point anywhere else.
    public var fileName: String {
        "\(id.uuidString).jpg"
    }
}

extension LocalDate {
    /// The Monday of this date's week (weeks start on Monday, as in Poland).
    public var startOfWeek: LocalDate {
        adding(days: 1 - isoWeekday)
    }
}

extension AppData {
    /// Her intention for `day`; empty when she hasn't set one.
    public func intention(on day: LocalDate) -> String {
        intentions[day] ?? ""
    }

    /// Sets the intention of `day`; an empty one is removed.
    public mutating func setIntention(_ text: String, on day: LocalDate) {
        intentions[day] = AppData.isBlank(text) ? nil : text
    }

    /// The reflection of the week `day` falls in.
    public func reflection(forWeekOf day: LocalDate) -> WeeklyReflection? {
        reflections[day.startOfWeek]
    }

    /// Saves the reflection of the week `day` falls in (stored under its Monday). Nil or an empty
    /// answer removes it.
    public mutating func setReflection(_ reflection: WeeklyReflection?, forWeekOf day: LocalDate) {
        if let reflection, !AppData.isBlank(reflection.answer) {
            reflections[day.startOfWeek] = reflection
        } else {
            reflections[day.startOfWeek] = nil
        }
    }

    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
