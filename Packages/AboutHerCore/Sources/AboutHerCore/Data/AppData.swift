import Foundation

/// Everything she logs. Stored as one JSON file; this same file is the backup format.
///
/// Every field decodes with a default, so files written by older versions keep loading
/// when new fields are added – and every such addition still raises `currentSchemaVersion`.
public struct AppData: Codable, Sendable, Equatable {
    /// 2: food (meals, taught products, water, weight, profile, targets).
    ///
    /// Raise it for every new stored field and every new enum case, nested ones included (in a
    /// meal, a product, a portion, the profile, the targets …). An older version recognises a
    /// newer file only by this number, by its top-level keys and by whether it can decode the
    /// file at all (`AppDataCoding.isFromNewerVersion`); a nested field it doesn't know it would
    /// drop without a word on its next save. Never remove or rename a field or a case either:
    /// older files would then read as coming from a newer version and stay read-only.
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

    /// Replaces what she typed for a meal and what it was parsed into. The meal keeps its id,
    /// its time and its place in the day. Does nothing when there is no such meal on `day`.
    public mutating func updateMeal(id: UUID, on day: LocalDate, text: String, parsed: ParsedMeal) {
        guard var entries = meals[day], let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].update(text: text, parsed: parsed)
        meals[day] = entries
    }

    /// Adds a product she taught the app – replacing an earlier one with the same id or name, so
    /// teaching it again corrects it – then parses again every entry that had unrecognised parts
    /// or used the replaced product, so the change counts in days already logged too.
    ///
    /// Taught again under its name (a new id), the product keeps the earlier one's name and forms
    /// as aliases, so the meals she logged with them keep counting. Saved under its own id, it is
    /// an edit of that product: the sheet showed its forms, so they are taken as she left them.
    /// The product stays where the replaced one was, so which of her products wins a shared
    /// alias doesn't change.
    public mutating func teachFood(_ item: FoodItem, catalog: FoodCatalog) {
        var item = item
        let name = FoodText.normalized(item.name)
        let replacedFoods = userFoods.filter { $0.id == item.id || FoodText.normalized($0.name) == name }
        let replaced = Set(replacedFoods.map(\.id))
        var forms = Set([name] + item.aliases.map(FoodText.normalized))
        for earlier in replacedFoods where earlier.id != item.id {
            for form in [earlier.name] + earlier.aliases {
                let normalized = FoodText.normalized(form)
                if !normalized.isEmpty && forms.insert(normalized).inserted {
                    item.aliases.append(form)
                }
            }
        }
        let position = userFoods.firstIndex { replaced.contains($0.id) } ?? userFoods.endIndex
        userFoods.removeAll { replaced.contains($0.id) }
        userFoods.insert(item, at: Swift.min(position, userFoods.endIndex))
        let parser = MealParser(catalog: catalog, userFoods: userFoods)
        func needsParsing(_ entry: MealEntry) -> Bool {
            !entry.unknown.isEmpty || entry.items.contains { replaced.contains($0.foodID) }
        }
        for (day, entries) in meals where entries.contains(where: needsParsing) {
            meals[day] = entries.map { needsParsing($0) ? $0.reparsed(with: parser) : $0 }
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
    /// a top-level field this version doesn't know, or a JSON object this version can't decode
    /// (say, a new enum value deep inside a meal or a product). Such a file must never be saved
    /// back by this version, because what it doesn't know would be lost.
    ///
    /// The app writes its file atomically, so a well-formed JSON object it can't decode almost
    /// certainly comes from another version, not from damage: it is opened read-only instead of
    /// being set aside. Bytes that aren't a JSON object still count as damaged (`false` here).
    /// Unknown keys deeper in the file can't be seen at all – see `AppData.currentSchemaVersion`.
    public static func isFromNewerVersion(_ raw: Data) -> Bool {
        guard let topLevel = try? JSONDecoder().decode(TopLevelKeys.self, from: raw) else { return false }
        if let version = topLevel.schemaVersion, version > AppData.currentSchemaVersion {
            return true
        }
        let known = Set(AppData.CodingKeys.allCases.map(\.rawValue))
        if !topLevel.keys.isSubset(of: known) {
            return true
        }
        do {
            _ = try decode(raw)
            return false
        } catch {
            return true
        }
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
