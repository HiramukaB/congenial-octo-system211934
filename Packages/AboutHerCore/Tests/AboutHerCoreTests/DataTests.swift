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
        #expect(old.meals.isEmpty && old.water.isEmpty && old.weights.isEmpty)
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

    @Test func recognisesFilesWrittenByANewerVersion() throws {
        #expect(!AppDataCoding.isFromNewerVersion(try AppDataCoding.encode(AppData())))
        #expect(!AppDataCoding.isFromNewerVersion(Data("{}".utf8)))
        #expect(!AppDataCoding.isFromNewerVersion(Data("not json".utf8)))
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":3,"periodDays":[]}"#.utf8)))
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":2,"periodDays":[],"recipePlan":[]}"#.utf8)))
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
