import Foundation

/// The numbers she types about herself and for her own daily targets, read with the same rules as
/// the targets in "jedzenie": a birth year in full, a height in centimetres (or in metres, "1,65"),
/// a weight in kilograms, and her own kcal and grams. Text comes as typed, with a decimal comma or
/// a point; anything that can't be right reads as nil, so it is never saved.
public enum BodyNumbers {
    /// The earliest birth year that counts.
    public static let earliestBirthYear = 1920
    /// A birth year at most this many years before the current one.
    public static let youngestAge = 10
    /// Centimetres.
    public static let heightRange: ClosedRange<Double> = 120...220
    /// A height in this range is in metres ("1,65").
    public static let metresRange: ClosedRange<Double> = 1.2...2.2
    /// Kilograms; the same range a weigh-in may have.
    public static let weightRange: ClosedRange<Double> = 25...250
    /// Her own kcal for a whole day. Outside it a number is more likely a typo.
    public static let dailyKcalRange: ClosedRange<Double> = 800...4000

    /// "62,4", "62.4" or " 70 " as a number; nil for anything else, NaN and infinity included.
    public static func number(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    /// A year in full, from 1920 up to ten years before `currentYear`: "1995". Nil for "95".
    public static func birthYear(_ text: String, currentYear: Int) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let year = Int(trimmed), year >= earliestBirthYear, year <= currentYear - youngestAge else {
            return nil
        }
        return year
    }

    /// Centimetres, 120–220; "1,65" is in metres and reads as 165.
    public static func heightCm(_ text: String) -> Double? {
        guard var value = number(text) else { return nil }
        if metresRange.contains(value) {
            value = (value * 1000).rounded() / 10
        }
        return heightRange.contains(value) ? value : nil
    }

    /// Kilograms, 25–250.
    public static func weightKg(_ text: String) -> Double? {
        guard let value = number(text), weightRange.contains(value) else { return nil }
        return value
    }

    /// Her own kcal for a day, 800–4000.
    public static func dailyKcal(_ text: String) -> Double? {
        guard let value = number(text), dailyKcalRange.contains(value) else { return nil }
        return value
    }

    /// Grams of one of her own targets: 0 or more.
    public static func grams(_ text: String) -> Double? {
        guard let value = number(text), value >= 0 else { return nil }
        return value
    }

    /// Her own targets from the four fields; nil while one is empty or can't be right.
    public static func ownTargets(kcal: String, protein: String, carbs: String, fat: String) -> Macros? {
        guard let kcal = dailyKcal(kcal),
              let protein = grams(protein),
              let carbs = grams(carbs),
              let fat = grams(fat)
        else { return nil }
        return Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    /// A value put back into a field: "64,5", "165", "64,25" – rounded to two decimals, no trailing
    /// zeros, a decimal comma. `number` reads it again. NaN and infinity show as "0"; values beyond
    /// any real amount are capped, so it never traps.
    public static func text(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let limit = 1e12
        var hundredths = Int((Swift.min(Swift.max(value, -limit), limit) * 100).rounded())
        let isNegative = hundredths < 0
        if isNegative {
            hundredths = -hundredths
        }
        var text = String(hundredths / 100)
        let fraction = hundredths % 100
        if fraction != 0 {
            let digits = fraction < 10 ? "0\(fraction)" : "\(fraction)"
            text += "," + (digits.hasSuffix("0") ? String(digits.dropLast()) : digits)
        }
        return isNegative ? "-" + text : text
    }

    /// A whole number to show. Never traps: NaN and infinity are 0, and values far beyond any real
    /// amount are capped.
    public static func whole(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let limit = 1e15
        return Int(Swift.min(Swift.max(value, -limit), limit).rounded())
    }
}
