/// How "dziś" names the day it shows: a greeting for today, how long ago it was for the days
/// before. Polish words, like `PolishDate`.
public enum DayHeading {
    /// The hours that get "dzień dobry"; the evening and the night get "dobry wieczór".
    public static let dayHours = 5..<18

    /// "dzień dobry" from 5:00 until 17:59, otherwise "dobry wieczór" – with her name when she
    /// gave one: "dzień dobry, Ola". A blank name counts as none.
    public static func greeting(hour: Int, name: String?) -> String {
        let words = dayHours.contains(hour) ? "dzień dobry" : "dobry wieczór"
        guard let name = OnboardingState.cleanName(name) else { return words }
        return "\(words), \(name)"
    }

    /// "wczoraj", "przedwczoraj", "3 dni temu" for a day before `today`; nil for today and later.
    public static func pastDay(_ day: LocalDate, today: LocalDate) -> String? {
        let days = day.days(to: today)
        switch days {
        case ...0:
            return nil
        case 1:
            return "wczoraj"
        case 2:
            return "przedwczoraj"
        default:
            return "\(days) dni temu"
        }
    }
}
