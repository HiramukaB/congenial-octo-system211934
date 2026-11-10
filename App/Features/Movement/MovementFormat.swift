import Foundation
import AboutHerCore

/// Polish words for the movement tab.
enum MovementFormat {
    /// "10–15 min", "20 min"
    static func minutes(_ range: ClosedRange<Int>) -> String {
        range.lowerBound == range.upperBound
            ? "\(range.lowerBound) min"
            : "\(range.lowerBound)–\(range.upperBound) min"
    }

    /// "1 minuta", "3 minuty", "30 minut" – for VoiceOver.
    static func spokenMinutes(_ count: Int) -> String {
        "\(count) " + PolishPlural.form(count, one: "minuta", few: "minuty", many: "minut")
    }

    /// "ok. 114 kcal": movement kcal are always an estimate. Never traps on a strange value.
    static func kcal(_ value: Double) -> String {
        let whole = value.isFinite ? Int(Swift.min(Swift.max(value, 0), 100_000).rounded()) : 0
        return "ok. \(whole) kcal"
    }

    static func stageName(_ stage: Int) -> String {
        switch stage {
        case ...1: "start"
        case 2: "buduj"
        default: "pełny rytm"
        }
    }

    /// What a stage means, in one short line.
    static func stageDetail(_ stage: Int) -> String {
        switch stage {
        case ...1: "10–15 min, mobilność i łagodna joga – budujesz nawyk, nie formę"
        case 2: "15–20 min, dochodzi trening z ciężarem ciała"
        default: "20–30 min, dopasowane do fazy cyklu i Twojej energii"
        }
    }

    /// A day of the last week in a list: "dziś", "wczoraj", "sobota"; older ones "3 listopada".
    static func recentDay(_ day: LocalDate, today: LocalDate) -> String {
        switch day.days(to: today) {
        case 0: "dziś"
        case 1: "wczoraj"
        case 2...6: weekdays[weekdayIndex(day)]
        default: PolishDate.dayMonth(day)
        }
    }

    /// The editor's question: "co dziś robiłaś?", "co robiłaś wczoraj?", "co robiłaś w sobotę?".
    static func question(for day: LocalDate, today: LocalDate) -> String {
        switch day.days(to: today) {
        case 0: "co dziś robiłaś?"
        case 1: "co robiłaś wczoraj?"
        case 2...6: "co robiłaś \(onWeekdays[weekdayIndex(day)])?"
        default: "co robiłaś \(PolishDate.dayMonth(day))?"
        }
    }

    /// Monday first, like `LocalDate.isoWeekday`.
    static let weekdays = ["poniedziałek", "wtorek", "środa", "czwartek", "piątek", "sobota", "niedziela"]
    /// "w sobotę": the weekdays after "kiedy?".
    static let onWeekdays = ["w poniedziałek", "we wtorek", "w środę", "w czwartek", "w piątek", "w sobotę", "w niedzielę"]

    /// 0 for Monday … 6 for Sunday, safe for any date.
    static func weekdayIndex(_ day: LocalDate) -> Int {
        ((day.isoWeekday - 1) % 7 + 7) % 7
    }
}

extension WorkoutKind {
    var label: String {
        switch self {
        case .walk: "spacer"
        case .yoga: "joga"
        case .stretching: "rozciąganie"
        case .pilates: "pilates"
        case .strength: "trening siłowy"
        case .intervals: "interwały"
        case .dance: "taniec"
        case .running: "bieganie"
        case .cycling: "rower"
        case .swimming: "pływanie"
        case .other: "coś innego"
        }
    }
}

extension MovementVideo {
    /// What the video is.
    var title: String {
        switch self {
        case .gentleYoga: "joga dla początkujących"
        case .periodYoga: "joga na czas okresu"
        case .strength: "trening siłowy z hantlami"
        case .intervals: "interwały – HIIT"
        case .bodyweight: "full body bez sprzętu"
        }
    }

    /// Where it comes from.
    var source: String {
        switch self {
        case .gentleYoga: "Yoga with Adriene · YouTube"
        case .periodYoga: "relaksacja · YouTube"
        case .strength: "full body · YouTube"
        case .intervals, .bodyweight: "film na YouTube"
        }
    }
}

extension MovementSuggestion {
    /// What to do.
    var title: String {
        switch focus {
        case .habit: "mobilność i łagodna joga"
        case .gentle: "łagodna joga albo spacer"
        case .bodyweight: "trening z ciężarem ciała"
        case .lowEnergy: "łagodna joga"
        case .recovery: "joga albo spacer"
        case .strength: "trening siłowy"
        case .highEnergy: kind == .intervals ? "interwały" : "trening siłowy"
        case .moderate: "umiarkowany trening"
        }
    }

    /// Why, gently, in one short line.
    var detail: String {
        switch focus {
        case .habit: "spokojnie, bez pośpiechu – teraz liczy się nawyk, nie zmęczenie"
        case .gentle: "dziś łagodnie – joga albo spacer w zupełności wystarczą"
        case .bodyweight: "lekki trening z ciężarem własnego ciała – dasz radę"
        case .lowEnergy: "zaznaczyłaś niską energię, więc dziś łagodnie – to też trening"
        case .recovery: "czas na regenerację – tyle, ile masz dziś siły"
        case .strength: "energia zwykle rośnie – dobry moment na trening siłowy"
        case .highEnergy: "masz dziś dużo energii – daj sobie więcej, w swoim tempie"
        case .moderate: "spokojny, umiarkowany trening, bez forsowania się"
        }
    }
}
