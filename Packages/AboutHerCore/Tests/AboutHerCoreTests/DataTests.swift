import Foundation
import Testing
@testable import AboutHerCore

@Suite("Data and wording")
struct DataTests {
    @Test func appDataRoundTripsWithSortedDays() throws {
        var appData = AppData()
        appData.togglePeriodDay(LocalDate(year: 2025, month: 3, day: 2))
        appData.togglePeriodDay(LocalDate(year: 2025, month: 3, day: 1))

        let encoded = try AppDataCoding.encode(appData)
        let json = String(decoding: encoded, as: UTF8.self)
        let earlier = try #require(json.range(of: "2025-03-01"))
        let later = try #require(json.range(of: "2025-03-02"))
        #expect(earlier.lowerBound < later.lowerBound)
        #expect(try AppDataCoding.decode(encoded) == appData)
    }

    @Test func missingFieldsFallBackToDefaults() throws {
        let appData = try AppDataCoding.decode(Data("{}".utf8))
        #expect(appData.periodDays.isEmpty)
        #expect(appData.schemaVersion == AppData.currentSchemaVersion)
    }

    @Test func foodDataRoundTripsAndOlderFilesStillLoad() throws {
        let day = LocalDate(year: 2026, month: 3, day: 2)
        var appData = AppData()
        let item = FoodItem(id: "user-pierogi", name: "pierogi", aliases: ["pierogów"], category: .dishes,
                            per100: Macros(kcal: 200, protein: 7, carbs: 30, fat: 6),
                            defaultPortion: Portion(unit: .piece, grams: 40))
        appData.userFoods = [item]
        let parsed = ParsedMeal(items: [], unknown: ["coś nowego"], totals: .zero)
        appData.addMeal(MealEntry(createdAt: Date(timeIntervalSince1970: 1_800_000_000), text: "coś nowego", parsed: parsed),
                        on: day)
        appData.addWater(3, to: .morning, on: day)
        appData.addWater(-5, to: .midday, on: day)
        appData.setWeight(64.5, on: day)
        appData.nutritionProfile = NutritionProfile(birthYear: 1990, heightCm: 170, weightKg: 65,
                                                    activity: .light, deficitKcal: 300)
        appData.targetsSetting = .manual(Macros(kcal: 1800, protein: 110, carbs: 200, fat: 60))

        let encoded = try AppDataCoding.encode(appData)
        let decoded = try AppDataCoding.decode(encoded)
        #expect(decoded == appData)
        #expect(decoded.water(on: day) == WaterDay(morning: 3, midday: 0, evening: 0))
        #expect(!AppDataCoding.isFromNewerVersion(encoded))

        // A file written before food existed (schema 1) loads with empty food data.
        let old = try AppDataCoding.decode(Data(#"{"schemaVersion":1,"periodDays":["2026-03-01"]}"#.utf8))
        #expect(old.periodDays == [LocalDate(year: 2026, month: 3, day: 1)])
        #expect(old.meals.isEmpty && old.water.isEmpty && old.weights.isEmpty && old.userFoods.isEmpty)
        #expect(old.nutritionProfile == nil)
        #expect(old.targetsSetting == .automatic)
        #expect(!AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":1,"periodDays":[]}"#.utf8)))
    }

    @Test func waterNeverGoesBelowZeroAndEmptyDaysDisappear() {
        let day = LocalDate(year: 2026, month: 3, day: 2)
        var appData = AppData()
        appData.addWater(1, to: .evening, on: day)
        appData.addWater(-3, to: .evening, on: day)
        #expect(appData.water(on: day).total == 0)
        #expect(appData.water[day] == nil)
    }

    @Test func removingTheLastMealOfADayRemovesTheDay() {
        let day = LocalDate(year: 2026, month: 3, day: 2)
        var appData = AppData()
        let entry = MealEntry(text: "x", parsed: ParsedMeal(items: [], unknown: ["x"], totals: .zero))
        appData.addMeal(entry, on: day)
        appData.removeMeal(id: entry.id, on: day)
        #expect(appData.meals.isEmpty)
    }

    @Test func updatingAMealKeepsItsIdTimeAndPlace() throws {
        let day = LocalDate(year: 2026, month: 3, day: 2)
        let unknown = ParsedMeal(items: [], unknown: ["coś"], totals: .zero)
        let first = MealEntry(createdAt: Date(timeIntervalSince1970: 1_800_000_000), text: "pierwszy", parsed: unknown)
        let second = MealEntry(createdAt: Date(timeIntervalSince1970: 1_800_003_600), text: "drugi", parsed: unknown)
        let third = MealEntry(createdAt: Date(timeIntervalSince1970: 1_800_007_200), text: "trzeci", parsed: unknown)
        var appData = AppData()
        for entry in [first, second, third] {
            appData.addMeal(entry, on: day)
        }

        let item = ParsedItem(text: "200 g twarogu", foodID: "user-twarog", foodName: "twaróg", amount: 200, unit: nil,
                              grams: 200, macros: Macros(kcal: 260, protein: 36, carbs: 7, fat: 9))
        let corrected = ParsedMeal(items: [item], unknown: [])
        appData.updateMeal(id: second.id, on: day, text: "200 g twarogu", parsed: corrected)

        let meals = appData.meals(on: day)
        try #require(meals.count == 3)
        #expect(meals.map(\.id) == [first.id, second.id, third.id])
        #expect(meals[1].createdAt == second.createdAt)
        #expect(meals[1].text == "200 g twarogu")
        #expect(meals[1].items == [item])
        #expect(meals[1].unknown.isEmpty)
        #expect(meals[1].totals == Macros(kcal: 260, protein: 36, carbs: 7, fat: 9))
        #expect(meals[0] == first)
        #expect(meals[2] == third)
        #expect(appData.eaten(on: day).kcal == 260)

        // An id that isn't on that day changes nothing – not even the same meal asked for on another day.
        let before = appData
        appData.updateMeal(id: UUID(), on: day, text: "y", parsed: unknown)
        appData.updateMeal(id: second.id, on: day.adding(days: 1), text: "y", parsed: unknown)
        #expect(appData == before)
        #expect(appData.meals[day.adding(days: 1)] == nil)
    }

    @Test func teachingAProductCountsItInEarlierMealsAndTeachingItAgainCorrectsThem() throws {
        // Only her own products, so the test doesn't depend on what the built-in catalog knows.
        let catalog = FoodCatalog(items: [])
        let parser = MealParser(catalog: catalog)
        let day = LocalDate(year: 2026, month: 3, day: 2)
        let nextDay = day.adding(days: 1)
        var appData = AppData()
        appData.addMeal(MealEntry(text: "szakszuka", parsed: parser.parse("szakszuka")), on: day)
        appData.addMeal(MealEntry(text: "menemen", parsed: parser.parse("menemen")), on: nextDay)
        #expect(appData.meals(on: day).first?.unknown == ["szakszuka"])
        #expect(appData.meals(on: nextDay).first?.unknown == ["menemen"])

        // "menemen" is her own word for it, far from "szakszuka" (not a typo the parser would guess).
        let serving = Portion(unit: .serving, grams: 300)
        let taught = FoodItem(id: "user-1", name: "szakszuka", aliases: ["menemen"], category: .dishes,
                              per100: Macros(kcal: 100, protein: 6, carbs: 5, fat: 6), defaultPortion: serving)
        appData.teachFood(taught, catalog: catalog)
        #expect(appData.meals(on: day).first?.unknown.isEmpty == true)
        #expect(appData.eaten(on: day).kcal == 300)
        #expect(appData.eaten(on: nextDay).kcal == 300)

        // Taught again under its name with a new id (the sheet opened from another fragment): the old
        // values go, also in the meals already logged, and the forms she used before keep counting.
        let corrected = FoodItem(id: "user-2", name: "Szakszuka", category: .dishes,
                                 per100: Macros(kcal: 120, protein: 7, carbs: 5, fat: 8), defaultPortion: serving)
        appData.teachFood(corrected, catalog: catalog)
        #expect(appData.userFoods.map(\.id) == ["user-2"])
        #expect(appData.userFoods.first?.aliases == ["menemen"])
        #expect(appData.eaten(on: day).kcal == 360)
        #expect(appData.meals(on: nextDay).first?.unknown.isEmpty == true)
        #expect(appData.eaten(on: nextDay).kcal == 360)

        // Saved under its own id it is an edit, and the sheet showed its forms: one she removed stays removed.
        var edited = try #require(appData.userFoods.first)
        edited.aliases.removeAll { $0 == "menemen" }
        appData.teachFood(edited, catalog: catalog)
        #expect(appData.userFoods.map(\.id) == ["user-2"])
        #expect(appData.userFoods.first?.aliases.isEmpty == true)
        #expect(appData.meals(on: nextDay).first?.unknown == ["menemen"])
        #expect(appData.eaten(on: nextDay).kcal == 0)
        #expect(appData.eaten(on: day).kcal == 360)
    }

    @Test func anEditedProductKeepsItsPlaceAmongHerProducts() throws {
        let catalog = FoodCatalog(items: [])
        let serving = Portion(unit: .serving, grams: 100)
        var appData = AppData()
        // Both answer to "pierogi"; the one taught first wins it.
        appData.teachFood(FoodItem(id: "user-a", name: "pierogi ruskie", aliases: ["pierogi"], category: .dishes,
                                   per100: Macros(kcal: 200), defaultPortion: serving), catalog: catalog)
        appData.teachFood(FoodItem(id: "user-b", name: "pierogi z mięsem", aliases: ["pierogi"], category: .dishes,
                                   per100: Macros(kcal: 250), defaultPortion: serving), catalog: catalog)
        let day = LocalDate(year: 2026, month: 3, day: 2)
        let parser = MealParser(catalog: catalog, userFoods: appData.userFoods)
        appData.addMeal(MealEntry(text: "pierogi", parsed: parser.parse("pierogi")), on: day)
        #expect(appData.meals(on: day).first?.items.first?.foodID == "user-a")

        // New values for the first one: it stays first, so "pierogi" still means it.
        var edited = try #require(appData.userFoods.first)
        edited.per100 = Macros(kcal: 220)
        appData.teachFood(edited, catalog: catalog)
        #expect(appData.userFoods.map(\.id) == ["user-a", "user-b"])
        #expect(appData.meals(on: day).first?.items.first?.foodID == "user-a")
        #expect(appData.eaten(on: day).kcal == 220)
    }

    @Test func teachingAProductCountsAgainOnlyTheMealsItConcerns() throws {
        // A catalog of one, so the test doesn't depend on what the built-in catalog knows.
        let sernik = FoodItem(id: "sernik", name: "sernik", category: .sweets,
                              per100: Macros(kcal: 300, protein: 7, carbs: 25, fat: 18),
                              defaultPortion: Portion(unit: .serving, grams: 100))
        let catalog = FoodCatalog(items: [sernik])
        let day = LocalDate(year: 2026, month: 3, day: 2)
        // Both meals were counted when a serving of sernik still weighed 250 g; the catalog now says 100 g.
        let earlierSernik = ParsedItem(text: "sernik", foodID: "sernik", foodName: "sernik", amount: 1, unit: .serving,
                                       grams: 250, macros: Macros(kcal: 750, protein: 17.5, carbs: 62.5, fat: 45))
        let unrelated = MealEntry(text: "sernik, coś słodkiego",
                                  parsed: ParsedMeal(items: [earlierSernik], unknown: ["coś słodkiego"]))
        let waiting = MealEntry(text: "sernik, szakszuka",
                                parsed: ParsedMeal(items: [earlierSernik], unknown: ["szakszuka"]))
        var appData = AppData()
        appData.addMeal(unrelated, on: day)
        appData.addMeal(waiting, on: day)
        #expect(MealParser(catalog: catalog).parse(unrelated.text).totals != unrelated.totals)

        let taught = FoodItem(id: "user-1", name: "szakszuka", category: .dishes,
                              per100: Macros(kcal: 100, protein: 6, carbs: 5, fat: 6),
                              defaultPortion: Portion(unit: .serving, grams: 300))
        appData.teachFood(taught, catalog: catalog)

        // The meal it doesn't concern keeps what it was counted as, its unknown part too …
        let meals = appData.meals(on: day)
        try #require(meals.count == 2)
        #expect(meals[0] == unrelated)
        // … and the one whose unknown part it is, is counted again, with the catalog as it is now.
        #expect(meals[1].id == waiting.id)
        #expect(meals[1].unknown.isEmpty)
        #expect(meals[1].items.map(\.foodID) == ["sernik", "user-1"])
        #expect(meals[1].totals.kcal == 600)
        #expect(appData.eaten(on: day).kcal == 1350)
    }

    @Test func recognisesFilesWrittenByANewerVersion() throws {
        #expect(!AppDataCoding.isFromNewerVersion(try AppDataCoding.encode(AppData())))
        #expect(!AppDataCoding.isFromNewerVersion(Data("{}".utf8)))
        // Bytes that aren't a JSON object are damage, not a newer version.
        #expect(!AppDataCoding.isFromNewerVersion(Data("not json".utf8)))
        #expect(!AppDataCoding.isFromNewerVersion(Data("[]".utf8)))
        #expect(!AppDataCoding.isFromNewerVersion(Data()))
        let newer = AppData.currentSchemaVersion + 1
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":\#(newer),"periodDays":[]}"#.utf8)))
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":2,"periodDays":[],"recipePlan":[]}"#.utf8)))
    }

    @Test func aValueOnlyANewerVersionKnowsDeepInsideMakesTheFileReadOnlyNotDamaged() throws {
        func file(category: String) -> Data {
            Data("""
            {"schemaVersion":2,"periodDays":["2026-03-01"],"userFoods":[{"id":"user-kasza","name":"kasza z warzywami",
            "aliases":[],"category":"\(category)","per100":{"kcal":120,"protein":4,"carbs":20,"fat":3},
            "portions":[],"defaultPortion":{"unit":"serving","grams":250},"tags":[]}]}
            """.utf8)
        }
        // With a category this version knows, the file reads as usual …
        let known = file(category: "dishes")
        #expect(try AppDataCoding.decode(known).userFoods.first?.category == .dishes)
        #expect(!AppDataCoding.isFromNewerVersion(known))

        // … with one it doesn't, it can't be decoded, yet it is no damage: it is opened read-only,
        // never set aside or saved over.
        let newer = file(category: "nowa")
        #expect(throws: (any Error).self) {
            _ = try AppDataCoding.decode(newer)
        }
        #expect(AppDataCoding.isFromNewerVersion(newer))
    }

    @Test func aFileWrittenByVersion018ReadsAndWritesBackWithoutLosingAnything() throws {
        // The shape 0.1.8 writes (schema 2), every food field filled in. Made-up values.
        let raw = Data(#"""
        {
          "meals" : {
            "2026-03-02" : [
              {
                "createdAt" : "2026-03-02T07:45:00Z",
                "id" : "6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C",
                "items" : [
                  {
                    "amount" : 2,
                    "foodID" : "jajko",
                    "foodName" : "jajko",
                    "grams" : 110,
                    "isGuess" : false,
                    "macros" : { "carbs" : 0.66, "fat" : 10.67, "kcal" : 154, "protein" : 13.75 },
                    "text" : "2 jajka",
                    "unit" : "piece"
                  },
                  {
                    "amount" : 150,
                    "foodID" : "user-twarozek",
                    "foodName" : "twarożek z rzodkiewką",
                    "grams" : 150,
                    "isGuess" : true,
                    "macros" : { "carbs" : 6, "fat" : 7.5, "kcal" : 165, "protein" : 18 },
                    "text" : "150 g twarozku z rzodkiewka"
                  }
                ],
                "text" : "2 jajka, 150 g twarozku z rzodkiewka i coś słodkiego",
                "totals" : { "carbs" : 6.66, "fat" : 18.17, "kcal" : 319, "protein" : 31.75 },
                "unknown" : [ "coś słodkiego" ]
              }
            ]
          },
          "nutritionProfile" : {
            "activity" : "light",
            "birthYear" : 1990,
            "deficitKcal" : 300,
            "heightCm" : 170,
            "weightKg" : 65
          },
          "periodDays" : [ "2026-02-20", "2026-02-21" ],
          "schemaVersion" : 2,
          "targetsSetting" : {
            "macros" : { "carbs" : 190, "fat" : 55, "kcal" : 1650, "protein" : 110 },
            "mode" : "manual"
          },
          "userFoods" : [
            {
              "aliases" : [ "twarożku z rzodkiewką" ],
              "category" : "other",
              "defaultPortion" : { "grams" : 150, "unit" : "serving" },
              "id" : "user-twarozek",
              "name" : "twarożek z rzodkiewką",
              "per100" : { "carbs" : 4, "fat" : 5, "kcal" : 110, "protein" : 12 },
              "portions" : [ { "grams" : 150, "unit" : "serving" } ],
              "tags" : [ "protein", "calcium" ]
            }
          ],
          "water" : {
            "2026-03-02" : { "evening" : 0, "midday" : 2, "morning" : 3 }
          },
          "weights" : {
            "2026-02-23" : 65.4,
            "2026-03-02" : 64.9
          }
        }
        """#.utf8)
        #expect(!AppDataCoding.isFromNewerVersion(raw))
        let appData = try AppDataCoding.decode(raw)
        let day = LocalDate(year: 2026, month: 3, day: 2)
        let meal = try #require(appData.meals(on: day).first)
        #expect(meal.items.count == 2)
        #expect(meal.items.first?.unit == .piece)
        #expect(meal.items.last?.unit == nil)
        #expect(meal.unknown == ["coś słodkiego"])
        #expect(appData.water(on: day) == WaterDay(morning: 3, midday: 2, evening: 0))
        #expect(appData.weights[day] == 64.9)
        #expect(appData.nutritionProfile?.activity == .light)
        #expect(appData.targetsSetting == .manual(Macros(kcal: 1650, protein: 110, carbs: 190, fat: 55)))
        #expect(appData.userFoods.first?.tags == [NutrientTag.protein, .calcium])

        // Written back, every key and value is still there; only the version is the current one.
        let written = try AppDataCoding.encode(appData)
        let original = try JSONDecoder().decode(JSONValue.self, from: raw)
        let rewritten = try JSONDecoder().decode(JSONValue.self, from: written)
        #expect(rewritten == original.setting("schemaVersion", to: .number(Double(AppData.currentSchemaVersion))))
        var current = appData
        current.schemaVersion = AppData.currentSchemaVersion
        #expect(try AppDataCoding.decode(written) == current)
    }

    @Test func togglingTwiceRemovesTheDay() {
        var appData = AppData()
        let day = LocalDate(year: 2025, month: 5, day: 5)
        appData.togglePeriodDay(day)
        appData.togglePeriodDay(day)
        #expect(appData.periodDays.isEmpty)
    }

    @Test func polishWording() {
        let saturday = LocalDate(year: 2026, month: 11, day: 7)
        #expect(PolishDate.short(LocalDate(year: 2026, month: 9, day: 5)) == "5 wrz")
        #expect(PolishDate.dayMonth(saturday) == "7 listopada")
        #expect(PolishDate.long(saturday) == "sobota, 7 listopada")
        #expect(PolishDate.monthYear(saturday) == "listopad 2026")
        #expect(PolishDate.range(LocalDate(year: 2026, month: 8, day: 31), LocalDate(year: 2026, month: 9, day: 15)) == "31 sie – 15 wrz")
        #expect(PolishDate.range(LocalDate(year: 2026, month: 10, day: 24), LocalDate(year: 2026, month: 10, day: 28)) == "24–28 paź")
        #expect(PolishDate.range(saturday, saturday) == "7 lis")
        #expect(PolishPlural.days(1) == "1 dzień")
        #expect(PolishPlural.days(2) == "2 dni")
        #expect(PolishPlural.days(12) == "12 dni")
    }
}

/// Any JSON value, so two files can be compared key by key whatever their formatting.
/// A key holding null counts as missing.
private enum JSONValue: Decodable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            let fields = try container.decode([String: JSONValue].self)
            self = .object(fields.filter { $0.value != .null })
        }
    }

    /// The same object with `key` set to `value`.
    func setting(_ key: String, to value: JSONValue) -> JSONValue {
        guard case .object(let fields) = self else { return self }
        var updated = fields
        updated[key] = value
        return .object(updated)
    }
}
