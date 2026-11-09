/// Energy (kcal) and the three macronutrients (grams).
public struct Macros: Codable, Sendable, Hashable, AdditiveArithmetic {
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double

    public init(kcal: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    public static let zero = Macros()

    public static func + (lhs: Macros, rhs: Macros) -> Macros {
        Macros(kcal: lhs.kcal + rhs.kcal, protein: lhs.protein + rhs.protein,
               carbs: lhs.carbs + rhs.carbs, fat: lhs.fat + rhs.fat)
    }

    public static func - (lhs: Macros, rhs: Macros) -> Macros {
        Macros(kcal: lhs.kcal - rhs.kcal, protein: lhs.protein - rhs.protein,
               carbs: lhs.carbs - rhs.carbs, fat: lhs.fat - rhs.fat)
    }

    public func scaled(by factor: Double) -> Macros {
        Macros(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor)
    }

    /// Each value clamped at zero – what is left to a target, never negative.
    public var clampedAtZero: Macros {
        Macros(kcal: Swift.max(0, kcal), protein: Swift.max(0, protein),
               carbs: Swift.max(0, carbs), fat: Swift.max(0, fat))
    }

    /// Energy implied by the macronutrients (4 / 4 / 9 kcal per gram).
    public var kcalFromMacros: Double {
        4 * protein + 4 * carbs + 9 * fat
    }
}

extension Sequence where Element == Macros {
    public func sum() -> Macros {
        reduce(.zero, +)
    }
}
