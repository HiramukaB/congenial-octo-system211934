import Foundation

/// How an amount of food is counted when it isn't given in grams.
/// Raw values are stable English keys (used in FoodDB.json and in her data file);
/// the Polish words are handled by the meal parser and the UI.
public enum PortionUnit: String, Codable, Sendable, CaseIterable {
    case piece          // sztuka (jajko, bułka, jabłko)
    case slice          // kromka (chleb)
    case thinSlice      // plaster / plasterek (ser, szynka)
    case tablespoon     // łyżka
    case teaspoon       // łyżeczka
    case glass          // szklanka (250 ml)
    case mug            // kubek (300 ml)
    case handful        // garść
    case serving        // porcja (a typical serving of a dish)
    case bowl           // miska
    case can            // puszka
    case package        // opakowanie
    case chunk          // kawałek
    case clove          // ząbek
}

/// A typical portion of one product, with its weight.
public struct Portion: Codable, Sendable, Hashable {
    public var unit: PortionUnit
    public var grams: Double

    public init(unit: PortionUnit, grams: Double) {
        self.unit = unit
        self.grams = grams
    }
}

/// Nutrients a product is a notable source of – used to match food to the cycle phase.
public enum NutrientTag: String, Codable, Sendable, CaseIterable {
    case protein, iron, magnesium, fiber, omega3, calcium
}

public enum FoodCategory: String, Codable, Sendable, CaseIterable {
    case bread, dairy, eggs, meat, fish, legumes, grains, fats, nuts, fruit, vegetables, sweets, drinks, dishes, other
}

/// One product or dish. Values are per 100 g (or 100 ml for drinks, 1 ml ≈ 1 g).
public struct FoodItem: Codable, Sendable, Hashable, Identifiable {
    /// Stable ASCII slug, e.g. "maslo". Products she teaches the app start with "user-".
    public var id: String
    /// Dictionary form, as shown in the app: "masło".
    public var name: String
    /// Other forms and synonyms the parser should recognise: "masła", "masłem", "maselko".
    public var aliases: [String]
    public var category: FoodCategory
    public var per100: Macros
    /// Typical portions with their weight. The first one that matches a unit wins.
    public var portions: [Portion]
    /// What a bare count means: "2 jajka" = 2 × this portion.
    public var defaultPortion: Portion
    public var tags: [NutrientTag]

    public init(id: String, name: String, aliases: [String] = [], category: FoodCategory, per100: Macros,
                portions: [Portion] = [], defaultPortion: Portion, tags: [NutrientTag] = []) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.per100 = per100
        self.portions = portions
        self.defaultPortion = defaultPortion
        self.tags = tags
    }

    /// Macros of `grams` grams of this product.
    public func macros(grams: Double) -> Macros {
        per100.scaled(by: grams / 100)
    }

    /// The weight of one `unit` of this product: its own portion if it has one, otherwise a generic weight.
    public func grams(per unit: PortionUnit) -> Double {
        if defaultPortion.unit == unit { return defaultPortion.grams }
        return portions.first(where: { $0.unit == unit })?.grams ?? FoodItem.genericGrams(for: unit)
    }

    /// Fallback weights when a product doesn't list a unit.
    public static func genericGrams(for unit: PortionUnit) -> Double {
        switch unit {
        case .piece: 100
        case .slice: 35
        case .thinSlice: 15
        case .tablespoon: 15
        case .teaspoon: 5
        case .glass: 250
        case .mug: 300
        case .handful: 30
        case .serving: 250
        case .bowl: 350
        case .can: 400
        case .package: 150
        case .chunk: 50
        case .clove: 5
        }
    }
}
