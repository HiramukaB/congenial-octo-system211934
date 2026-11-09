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

    static func whole(_ value: Double) -> Int {
        value.isFinite ? Int(value.rounded()) : 0
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

    /// One recognised item, e.g. "jajko × 3 · 210 kcal" or "łosoś · 150 g · 300 kcal".
    static func itemLine(_ item: ParsedItem) -> String {
        var line = item.foodName
        if item.unit == nil {
            line += " · \(whole(item.grams)) g"
        } else if abs(item.amount - 1) > 0.001 {
            line += " × " + number(item.amount, decimals: item.amount.rounded() == item.amount ? 0 : 1)
        }
        if item.isGuess {
            line += " (?)"
        }
        return line + " · \(whole(item.macros.kcal)) kcal"
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
