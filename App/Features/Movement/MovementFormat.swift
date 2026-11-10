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

    /// "ok. 114 kcal": movement kcal are always an estimate.
    static func kcal(_ value: Double) -> String {
        "ok. \(FoodFormat.whole(value)) kcal"
    }

    static func stageName(_ stage: Int) -> String {
        switch stage {
        case ...1: "start"
        case 2: "buduj"
        default: "pełny rytm"
        }
    }

    /// What a stage means, as the web version explained it.
    static func stageDetail(_ stage: Int) -> String {
        switch stage {
        case ...1: "10–15 min, mobilność i łagodna joga. Przez cały cykl tak samo spokojnie, bo teraz budujesz nawyk, nie formę"
        case 2: "15–20 min, dochodzi trening z ciężarem ciała. Zaczynam delikatnie różnicować dni według fazy"
        default: "20–30 min dopasowane do fazy cyklu. Cokolwiek mówi kalendarz, Twoja energia z danego dnia zawsze jest ważniejsza"
        }
    }

    /// "dziś", "wczoraj", "poniedziałek, 9 listopada"
    static func dayTitle(_ day: LocalDate, today: LocalDate) -> String {
        switch day.days(to: today) {
        case 0: "dziś"
        case 1: "wczoraj"
        default: PolishDate.long(day)
        }
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
    var label: String {
        switch self {
        case .gentleYoga: "joga dla początkujących – Yoga with Adriene"
        case .periodYoga: "joga na czas okresu – relaksacja"
        case .strength: "trening siłowy full body z hantlami"
        case .intervals: "HIIT – interwały"
        case .bodyweight: "full body bez sprzętu"
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

    /// Why, gently.
    var detail: String {
        switch focus {
        case .habit: "spokojnie i bez pośpiechu – teraz chodzi o to, żeby się pojawić, nie żeby się zmęczyć"
        case .gentle: "dziś łagodnie – joga albo spacer w zupełności wystarczą"
        case .bodyweight: "lekki trening z ciężarem własnego ciała – dasz radę"
        case .lowEnergy: "zaznaczyłaś dziś niską energię, więc odpuszczamy plan z kalendarza. Łagodna joga to też trening"
        case .recovery: "czas na regenerację – joga albo spacer, tyle, ile masz dziś siły"
        case .strength: "energia zwykle rośnie – to dobry moment na trening siłowy"
        case .highEnergy: "masz dziś dużo energii – to dobry dzień, żeby dać sobie więcej, w swoim tempie"
        case .moderate: "spokojny, umiarkowany trening, bez forsowania się"
        }
    }
}
