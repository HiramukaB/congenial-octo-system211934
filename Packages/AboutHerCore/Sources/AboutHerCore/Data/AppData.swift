import Foundation

/// Everything she logs. Stored as one JSON file; this same file is the backup format.
///
/// Every field decodes with a default, so files written by older versions keep loading
/// when new fields are added.
public struct AppData: Codable, Sendable, Equatable {
    /// 2: food (meals, taught products, water, weight, profile, targets).
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    /// Days she marked as bleeding.
    public var periodDays: Set<LocalDate>
    /// What she ate, per day, in the order she logged it.
    public var meals: [LocalDate: [MealEntry]]
    /// Products she taught the app (values per 100 g, like the built-in catalog).
    public var userFoods: [FoodItem]
    /// Glasses of water per day.
    public var water: [LocalDate: WaterDay]
    /// Weigh-ins in kg.
    public var weights: [LocalDate: Double]
    /// What her daily targets are computed from; nil until she fills it in.
    public var nutritionProfile: NutritionProfile?
    /// Computed from the profile, or her own numbers.
    public var targetsSetting: TargetsSetting

    public init(periodDays: Set<LocalDate> = [],
                meals: [LocalDate: [MealEntry]] = [:],
                userFoods: [FoodItem] = [],
                water: [LocalDate: WaterDay] = [:],
                weights: [LocalDate: Double] = [:],
                nutritionProfile: NutritionProfile? = nil,
                targetsSetting: TargetsSetting = .automatic) {
        self.schemaVersion = AppData.currentSchemaVersion
        self.periodDays = periodDays
        self.meals = meals
        self.userFoods = userFoods
        self.water = water
        self.weights = weights
        self.nutritionProfile = nutritionProfile
        self.targetsSetting = targetsSetting
    }

    public mutating func togglePeriodDay(_ date: LocalDate) {
        if periodDays.contains(date) {
            periodDays.remove(date)
        } else {
            periodDays.insert(date)
        }
    }

    // MARK: - Food

    public func meals(on day: LocalDate) -> [MealEntry] {
        meals[day] ?? []
    }

    /// Everything eaten on `day`.
    public func eaten(on day: LocalDate) -> Macros {
        meals(on: day).map(\.totals).sum()
    }

    public mutating func addMeal(_ entry: MealEntry, on day: LocalDate) {
        meals[day, default: []].append(entry)
    }

    public mutating func removeMeal(id: UUID, on day: LocalDate) {
        meals[day]?.removeAll { $0.id == id }
        if meals[day]?.isEmpty == true {
            meals[day] = nil
        }
    }

    /// Adds or replaces a product she taught the app, then parses again every entry that had
    /// unrecognised parts, so the new product counts in days already logged.
    public mutating func teachFood(_ item: FoodItem, catalog: FoodCatalog) {
        userFoods.removeAll { $0.id == item.id }
        userFoods.append(item)
        let parser = MealParser(catalog: catalog, userFoods: userFoods)
        for (day, entries) in meals where entries.contains(where: { !$0.unknown.isEmpty }) {
            meals[day] = entries.map { $0.unknown.isEmpty ? $0 : $0.reparsed(with: parser) }
        }
    }

    public func water(on day: LocalDate) -> WaterDay {
        water[day] ?? WaterDay()
    }

    public mutating func addWater(_ delta: Int, to slot: WaterDay.Slot, on day: LocalDate) {
        var waterDay = water(on: day)
        waterDay.add(delta, to: slot)
        water[day] = waterDay.total == 0 ? nil : waterDay
    }

    /// Sets (or with nil removes) the weigh-in of `day`.
    public mutating func setWeight(_ kg: Double?, on day: LocalDate) {
        weights[day] = kg
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion, periodDays, meals, userFoods, water, weights, nutritionProfile, targetsSetting
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? AppData.currentSchemaVersion
        periodDays = Set(try container.decodeIfPresent([LocalDate].self, forKey: .periodDays) ?? [])
        meals = try container.decodeIfPresent([LocalDate: [MealEntry]].self, forKey: .meals) ?? [:]
        userFoods = try container.decodeIfPresent([FoodItem].self, forKey: .userFoods) ?? []
        water = try container.decodeIfPresent([LocalDate: WaterDay].self, forKey: .water) ?? [:]
        weights = try container.decodeIfPresent([LocalDate: Double].self, forKey: .weights) ?? [:]
        nutritionProfile = try container.decodeIfPresent(NutritionProfile.self, forKey: .nutritionProfile)
        targetsSetting = try container.decodeIfPresent(TargetsSetting.self, forKey: .targetsSetting) ?? .automatic
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Whatever version it was read from, it is written in the current format.
        try container.encode(AppData.currentSchemaVersion, forKey: .schemaVersion)
        // Sorted, so backups are readable and compare cleanly.
        try container.encode(periodDays.sorted(), forKey: .periodDays)
        try container.encode(meals, forKey: .meals)
        try container.encode(userFoods, forKey: .userFoods)
        try container.encode(water, forKey: .water)
        try container.encode(weights, forKey: .weights)
        try container.encodeIfPresent(nutritionProfile, forKey: .nutritionProfile)
        try container.encode(targetsSetting, forKey: .targetsSetting)
    }
}

public enum AppDataCoding {
    public static func encode(_ appData: AppData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Readable times ("2026-11-09T08:15:00Z") in her file and backups.
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(appData)
    }

    public static func decode(_ raw: Data) throws -> AppData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppData.self, from: raw)
    }

    /// True when the file was written by a newer version of the app: a higher schema version,
    /// or fields this version doesn't know. Such a file must never be saved back by this
    /// version, because the unknown fields would be lost.
    public static func isFromNewerVersion(_ raw: Data) -> Bool {
        guard let topLevel = try? JSONDecoder().decode(TopLevelKeys.self, from: raw) else { return false }
        if let version = topLevel.schemaVersion, version > AppData.currentSchemaVersion {
            return true
        }
        let known = Set(AppData.CodingKeys.allCases.map(\.rawValue))
        return !topLevel.keys.isSubset(of: known)
    }

    private struct TopLevelKeys: Decodable {
        let keys: Set<String>
        let schemaVersion: Int?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: AnyKey.self)
            keys = Set(container.allKeys.map(\.stringValue))
            schemaVersion = try? container.decode(Int.self, forKey: AnyKey(stringValue: "schemaVersion"))
        }
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }
}
