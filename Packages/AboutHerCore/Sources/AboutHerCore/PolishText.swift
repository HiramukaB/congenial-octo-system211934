/// Polish date wording used across the app ("5 wrz", "sobota, 7 listopada").
public enum PolishDate {
    static let shortMonths = ["sty", "lut", "mar", "kwi", "maj", "cze", "lip", "sie", "wrz", "paź", "lis", "gru"]
    static let genitiveMonths = ["stycznia", "lutego", "marca", "kwietnia", "maja", "czerwca",
                                 "lipca", "sierpnia", "września", "października", "listopada", "grudnia"]
    static let nominativeMonths = ["styczeń", "luty", "marzec", "kwiecień", "maj", "czerwiec",
                                   "lipiec", "sierpień", "wrzesień", "październik", "listopad", "grudzień"]
    static let weekdays = ["poniedziałek", "wtorek", "środa", "czwartek", "piątek", "sobota", "niedziela"]

    /// Column headers of a Monday-first calendar.
    public static let weekdayInitials = ["P", "W", "Ś", "C", "P", "S", "N"]

    /// "5 wrz"
    public static func short(_ date: LocalDate) -> String {
        "\(date.day) \(shortMonths[date.month - 1])"
    }

    /// "7 listopada"
    public static func dayMonth(_ date: LocalDate) -> String {
        "\(date.day) \(genitiveMonths[date.month - 1])"
    }

    /// "sobota, 7 listopada"
    public static func long(_ date: LocalDate) -> String {
        "\(weekdays[date.isoWeekday - 1]), \(dayMonth(date))"
    }

    /// "listopad 2026"
    public static func monthYear(_ date: LocalDate) -> String {
        "\(nominativeMonths[date.month - 1]) \(date.year)"
    }

    /// "24–28 paź" within one month, "31 sie – 15 wrz" across months, "9 lis" for a single day.
    public static func range(_ from: LocalDate, _ to: LocalDate) -> String {
        if from == to {
            return short(from)
        }
        if from.year == to.year && from.month == to.month {
            return "\(from.day)–\(to.day) \(shortMonths[to.month - 1])"
        }
        return "\(short(from)) – \(short(to))"
    }
}

public enum PolishPlural {
    /// "1 dzień", "2 dni", "12 dni"
    public static func days(_ count: Int) -> String {
        count == 1 ? "1 dzień" : "\(count) dni"
    }

    /// The form of a noun that goes with `count` – the word only.
    /// 1 → `one` ("szklanka"); 2–4, 22–24, 102–104 … but not 12–14 → `few` ("szklanki");
    /// everything else, 0 included → `many` ("szklanek"). Negative numbers use their absolute value.
    public static func form(_ count: Int, one: String, few: String, many: String) -> String {
        let n = count.magnitude  // UInt, so Int.min can't overflow
        if n == 1 {
            return one
        }
        let lastDigit = n % 10
        let lastTwoDigits = n % 100
        let endsInTwoToFour = lastDigit >= 2 && lastDigit <= 4
        let endsInTwelveToFourteen = lastTwoDigits >= 12 && lastTwoDigits <= 14
        return endsInTwoToFour && !endsInTwelveToFourteen ? few : many
    }

    /// "1 szklanka", "3 szklanki", "5 szklanek"
    public static func glasses(_ count: Int) -> String {
        "\(count) " + form(count, one: "szklanka", few: "szklanki", many: "szklanek")
    }
}
