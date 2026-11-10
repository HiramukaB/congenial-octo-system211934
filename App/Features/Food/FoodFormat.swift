import Foundation
import AboutHerCore

/// Polish number formatting for the food screens: decimal comma, real minus sign.
enum FoodFormat {
    /// "62,4"; `decimals: 0` gives whole numbers.
    static func number(_ value: Double, decimals: Int = 1) -> String {
        let fixed = String(format: "%.\(decimals)f", value)
        return fixed.replacingOccurrences(of: ".", with: ",").replacingOccurrences(of: "-", with: "−")
    }

    /// "+0,4" / "−1,2" / "0,0".
    static func signed(_ value: Double, decimals: Int = 1) -> String {
        let rounded = (value * pow(10, Double(decimals))).rounded() / pow(10, Double(decimals))
        if rounded > 0 { return "+" + number(rounded, decimals: decimals) }
        if rounded < 0 { return number(rounded, decimals: decimals) }
        return number(0, decimals: decimals)
    }

    /// A whole number for display. Never traps: values far beyond any real amount (a pasted run
    /// of digits) are capped, and NaN or infinity show as 0.
    static func whole(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        let limit = 1e15
        return Int(Swift.min(Swift.max(value, -limit), limit).rounded())
    }

    /// "3", "1,5", "0,25": at most two decimals, no trailing zeros. Also used to put a saved
    /// value back into a text field, where `parseNumber` reads it again.
    static func compact(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") {
            text.removeLast()
        }
        if text.hasSuffix(".") {
            text.removeLast()
        }
        if text == "-0" {
            text = "0"
        }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    /// "420 kcal · B 21 g · W 50 g · T 14 g"
    static func macrosLine(_ macros: Macros) -> String {
        "\(whole(macros.kcal)) kcal · B \(whole(macros.protein)) g · W \(whole(macros.carbs)) g · T \(whole(macros.fat)) g"
    }

    /// Reads "62,4" as well as "62.4".
    static func parseNumber(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }

    /// One recognised item, e.g. "jajko × 3 · 165 g · 236 kcal" or "łosoś · 150 g · 300 kcal".
    /// Counted items show their grams too, so a wrong portion weight is visible at once.
    /// "(?)" follows the name when it was matched despite a typo.
    static func itemLine(_ item: ParsedItem) -> String {
        var line = item.foodName
        if item.isGuess {
            line += " (?)"
        }
        if item.unit != nil, abs(item.amount - 1) > 0.001 {
            line += " × " + compact(item.amount)
        }
        return line + " · \(whole(item.grams)) g · \(whole(item.macros.kcal)) kcal"
    }
}

extension PortionUnit {
    /// The Polish name of one unit, as in "1 łyżka".
    var label: String {
        switch self {
        case .piece: "sztuka"
        case .slice: "kromka"
        case .thinSlice: "plaster"
        case .tablespoon: "łyżka"
        case .teaspoon: "łyżeczka"
        case .glass: "szklanka"
        case .mug: "kubek"
        case .handful: "garść"
        case .serving: "porcja"
        case .bowl: "miska"
        case .can: "puszka"
        case .package: "opakowanie"
        case .chunk: "kawałek"
        case .clove: "ząbek"
        }
    }
}

extension ActivityLevel {
    var label: String {
        switch self {
        case .sedentary: "siedzący, bez treningów"
        case .light: "lekki – 1–3 treningi w tygodniu"
        case .moderate: "umiarkowany – 3–5 treningów"
        case .high: "wysoki – 6–7 treningów"
        }
    }
}

extension WaterDay.Slot {
    var label: String {
        switch self {
        case .morning: "rano"
        case .midday: "popołudnie"
        case .evening: "wieczór"
        }
    }

    var hours: String {
        switch self {
        case .morning: "do 13:00"
        case .midday: "13:00–20:00"
        case .evening: "po 20:00"
        }
    }
}
