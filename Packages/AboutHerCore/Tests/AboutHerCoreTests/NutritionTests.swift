import Foundation
import Testing
@testable import AboutHerCore

// Every profile and weigh-in here is made up; expected numbers come from a Python mirror of the code.
@Suite("Nutrition")
struct NutritionTests {
    /// A hypothetical profile. Defaults: 35 years old in 2026, 165 cm, 70 kg, light activity, −300 kcal.
    private func hypothetical(born: Int = 1991, height: Double = 165, weight: Double = 70,
                              activity: ActivityLevel = .light, deficit: Double = 300) -> NutritionProfile {
        NutritionProfile(birthYear: born, heightCm: height, weightKg: weight, activity: activity, deficitKcal: deficit)
    }

    /// Doubles compared with a tolerance (`pow` may differ in the last bit between C libraries).
    private func near(_ value: Double?, _ expected: Double, within tolerance: Double = 1e-9) -> Bool {
        guard let value else { return false }
        return abs(value - expected) <= tolerance
    }

    // MARK: - Targets

    @Test func activityMultipliers() {
        #expect(ActivityLevel.allCases.map(\.multiplier) == [1.2, 1.375, 1.55, 1.725])
    }

    @Test func typicalProfile() {
        let result = TargetCalculator.compute(profile: hypothetical(), year: 2026)
        #expect(result.bmr == 1395.25)
        #expect(result.tdee == 1918.46875)
        #expect(result.appliedDeficit == 300)
        #expect(result.adjustments.isEmpty)
        #expect(result.targets == Macros(kcal: 1618, protein: 126, carbs: 153, fat: 56))
    }

    @Test func deficitIsCappedAtAFifthOfTDEE() {
        let result = TargetCalculator.compute(profile: hypothetical(deficit: 600), year: 2026)
        #expect(result.adjustments == [.deficitLimited])
        #expect(near(result.appliedDeficit, 383.69375))
        #expect(near(result.appliedDeficit, 0.2 * result.tdee))
        #expect(result.targets == Macros(kcal: 1535, protein: 126, carbs: 132, fat: 56))
    }

    @Test func smallSedentaryProfileNeverGoesBelowTheFloor() {
        // 150 cm, 50 kg, 40 years, asking for 700 kcal less a day:
        // the web version said 592 kcal and −16 g of carbohydrates.
        let small = hypothetical(born: 1986, height: 150, weight: 50, activity: .sedentary, deficit: 700)
        let result = TargetCalculator.compute(profile: small, year: 2026)
        #expect(result.bmr == 1076.5)
        #expect(near(result.tdee, 1291.8))
        #expect(result.adjustments == [.deficitLimited, .raisedToMinimum])
        #expect(result.targets == Macros(kcal: 1200, protein: 90, carbs: 120, fat: 40))
        #expect(near(result.appliedDeficit, 91.8))
        #expect(result.targets.carbs >= 0)
    }

    @Test func noDeficitWhenTDEEIsBelowTheMinimum() {
        let small = hypothetical(born: 1966, height: 148, weight: 45, activity: .sedentary, deficit: 300)
        let result = TargetCalculator.compute(profile: small, year: 2026)
        #expect(near(result.tdee, 1096.8))
        #expect(result.appliedDeficit == 0)
        #expect(result.adjustments == [.deficitLimited, .raisedToMinimum])
        #expect(result.targets == Macros(kcal: 1097, protein: 81, carbs: 112, fat: 36))
    }

    @Test func maintenance() {
        let result = TargetCalculator.compute(profile: hypothetical(deficit: 0), year: 2026)
        #expect(result.appliedDeficit == 0)
        #expect(result.adjustments.isEmpty)
        #expect(result.targets == Macros(kcal: 1918, protein: 126, carbs: 228, fat: 56))
        // A negative deficit (a surplus) isn't offered; it counts as maintenance.
        #expect(TargetCalculator.compute(profile: hypothetical(deficit: -250), year: 2026) == result)

        let moderate = hypothetical(born: 1996, height: 172, weight: 64, activity: .moderate, deficit: 0)
        let other = TargetCalculator.compute(profile: moderate, year: 2026)
        #expect(other.adjustments.isEmpty)
        #expect(other.targets == Macros(kcal: 2176, protein: 115, carbs: 293, fat: 60))
    }

    @Test func proteinThenFatMakeRoomForCarbohydrates() {
        // 1.8 g/kg of protein and 0.8 g/kg of fat would leave 37 g of carbohydrates here.
        let heavier = hypothetical(born: 1976, height: 160, weight: 100, activity: .sedentary, deficit: 500)
        let both = TargetCalculator.compute(profile: heavier, year: 2026)
        #expect(both.adjustments == [.deficitLimited, .raisedToMinimum, .proteinLowered, .fatLowered])
        #expect(both.targets == Macros(kcal: 1589, protein: 160, carbs: 100, fat: 61))

        // Only as far as needed: here a little less protein is enough.
        let active = hypothetical(born: 1976, height: 152, weight: 100, activity: .light, deficit: 300)
        let proteinOnly = TargetCalculator.compute(profile: active, year: 2026)
        #expect(proteinOnly.adjustments == [.proteinLowered])
        #expect(proteinOnly.targets == Macros(kcal: 1816, protein: 174, carbs: 100, fat: 80))
    }

    @Test func carbohydratesBelowTheMinimumAreAcceptedButNeverNegative() {
        let tiny = hypothetical(born: 1936, height: 140, weight: 40, activity: .sedentary, deficit: 300)
        let accepted = TargetCalculator.compute(profile: tiny, year: 2026)
        #expect(accepted.adjustments == TargetAdjustment.allCases)
        #expect(accepted.targets == Macros(kcal: 797, protein: 64, carbs: 85, fat: 22))

        // Nonsense input (52 cm) still gives no negative carbohydrates.
        let nonsense = hypothetical(born: 1900, height: 52, weight: 200, activity: .sedentary, deficit: 1000)
        let clamped = TargetCalculator.compute(profile: nonsense, year: 2026)
        #expect(clamped.targets == Macros(kcal: 1664, protein: 320, carbs: 0, fat: 46))
    }

    @Test func trendWeightOverridesTheProfileWeight() {
        let result = TargetCalculator.compute(profile: hypothetical(), weightKg: 68, year: 2026)
        #expect(result.bmr == 1375.25)
        #expect(result.targets == Macros(kcal: 1591, protein: 122, carbs: 153, fat: 54))
        #expect(result == TargetCalculator.compute(profile: hypothetical(weight: 68), year: 2026))
    }

    @Test func ageIsClampedToFifteenThroughOneHundred() {
        let young = TargetCalculator.compute(profile: hypothetical(born: 2020, height: 160, weight: 50, deficit: 0),
                                             year: 2026)
        let fifteen = TargetCalculator.compute(profile: hypothetical(born: 2011, height: 160, weight: 50, deficit: 0),
                                               year: 2026)
        #expect(young.bmr == 1264)
        #expect(young == fifteen)

        let old = TargetCalculator.compute(profile: hypothetical(born: 1900, height: 160, weight: 60,
                                                                 activity: .sedentary, deficit: 0),
                                           year: 2026)
        let hundred = TargetCalculator.compute(profile: hypothetical(born: 1926, height: 160, weight: 60,
                                                                     activity: .sedentary, deficit: 0),
                                               year: 2026)
        #expect(old.bmr == 939)
        #expect(old == hundred)

        // A nonsense birth year (a damaged file) is clamped as well, without overflowing.
        #expect(TargetCalculator.compute(profile: hypothetical(born: Int.min), year: 2026) ==
                TargetCalculator.compute(profile: hypothetical(born: 1926), year: 2026))
        #expect(TargetCalculator.compute(profile: hypothetical(born: Int.max), year: 2026) ==
                TargetCalculator.compute(profile: hypothetical(born: 2011), year: 2026))
    }

    @Test func guardrailsHoldAcrossManyProfiles() {
        for height in stride(from: 140.0, through: 190.0, by: 10) {
            for weight in stride(from: 40.0, through: 160.0, by: 15) {
                for born in [1950, 1980, 2005] {
                    for activity in ActivityLevel.allCases {
                        for deficit in [0.0, 300, 700, 1200] {
                            let profile = hypothetical(born: born, height: height, weight: weight,
                                                       activity: activity, deficit: deficit)
                            checkGuardrails(TargetCalculator.compute(profile: profile, year: 2026), weight: weight)
                        }
                    }
                }
            }
        }
    }

    private func checkGuardrails(_ result: TargetResult, weight: Double) {
        let kcal = result.tdee - result.appliedDeficit
        let energyFloor = Swift.min(Swift.max(1200, result.bmr), result.tdee)
        #expect(kcal >= energyFloor - 1e-9)
        #expect(result.appliedDeficit >= 0)
        #expect(result.appliedDeficit <= 0.2 * result.tdee + 1e-9)
        #expect(abs(result.targets.kcal - kcal) <= 0.5 + 1e-9)
        #expect(result.targets.carbs >= 0)
        #expect(result.targets.protein >= (1.6 * weight).rounded())
        #expect(result.targets.protein <= (1.8 * weight).rounded())
        #expect(abs(result.targets.kcalFromMacros - result.targets.kcal) <= 9)
        let inOrder = TargetAdjustment.allCases.filter { result.adjustments.contains($0) }
        #expect(result.adjustments == inOrder)
    }

    // MARK: - Stored settings

    @Test func targetsSettingRoundTrips() throws {
        let manual = TargetsSetting.manual(Macros(kcal: 1700, protein: 120, carbs: 180, fat: 60))
        for setting in [TargetsSetting.automatic, manual] {
            let encoded = try JSONEncoder().encode(setting)
            #expect(try JSONDecoder().decode(TargetsSetting.self, from: encoded) == setting)
        }
        let automaticJSON = String(decoding: try JSONEncoder().encode(TargetsSetting.automatic), as: UTF8.self)
        #expect(automaticJSON == #"{"mode":"automatic"}"#)
        let manualJSON = String(decoding: try JSONEncoder().encode(manual), as: UTF8.self)
        #expect(manualJSON.contains(#""mode":"manual""#))
        #expect(manualJSON.contains(#""macros":{"#))
    }

    @Test func targetsSettingReadsWhatItCanUse() throws {
        func setting(_ json: String) throws -> TargetsSetting {
            try JSONDecoder().decode(TargetsSetting.self, from: Data(json.utf8))
        }
        #expect(try setting("{}") == .automatic)
        #expect(try setting(#"{"mode":"manual"}"#) == .automatic)
        #expect(try setting(#"{"mode":"perPhase","macros":{"kcal":1,"protein":1,"carbs":1,"fat":1}}"#) == .automatic)
        let withExtraKey = #"{"mode":"manual","macros":{"kcal":1650,"protein":110,"carbs":170,"fat":55},"since":"2026-11-09"}"#
        #expect(try setting(withExtraKey) == .manual(Macros(kcal: 1650, protein: 110, carbs: 170, fat: 55)))
        // Her own numbers are never dropped silently: damaged manual targets are an error.
        #expect(throws: (any Error).self) {
            _ = try setting(#"{"mode":"manual","macros":{"kcal":1650}}"#)
        }
    }

    @Test func profileRoundTrips() throws {
        let profile = hypothetical(activity: .moderate)
        let encoded = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(NutritionProfile.self, from: encoded) == profile)
        #expect(String(decoding: encoded, as: UTF8.self).contains(#""activity":"moderate""#))
    }

    // MARK: - Weight trend

    // Irregular, mostly weekly weigh-ins: gaps of 7, 8, 6, 14, 7 and 10 days.
    let firstWeighIn = LocalDate(year: 2026, month: 1, day: 5)
    let offsets = [0, 7, 15, 21, 35, 42, 52]
    let kilos = [80.0, 80.6, 79.4, 79.7, 78.9, 79.3, 78.4]

    var weighIns: [LocalDate: Double] {
        var weights: [LocalDate: Double] = [:]
        for (offset, kg) in zip(offsets, kilos) {
            weights[firstWeighIn.adding(days: offset)] = kg
        }
        return weights
    }

    @Test func trendSmoothsIrregularWeighIns() {
        let points = WeightTrend.points(weighIns)
        let days = offsets.map { firstWeighIn.adding(days: $0) }
        #expect(points.map(\.day) == days)
        #expect(points.map(\.kg) == kilos)
        let expected = [80.0, 80.23065667599653, 79.87708697864225, 79.81683383460667,
                        79.24741505796266, 79.26763017119232, 78.83381508559617]
        #expect(points.count == expected.count)
        for (point, trend) in zip(points, expected) {
            #expect(near(point.trend, trend))
        }
    }

    @Test func oneHalfLifeMovesTheTrendHalfway() {
        let start = LocalDate(year: 2026, month: 3, day: 2)
        #expect(near(WeightTrend.points([start: 80, start.adding(days: 10): 78]).last?.trend, 79))
        #expect(near(WeightTrend.points([start: 80, start.adding(days: 20): 76]).last?.trend, 77))

        let steady = WeightTrend.points([start: 70.5, start.adding(days: 3): 70.5, start.adding(days: 11): 70.5])
        #expect(steady.map(\.trend) == [70.5, 70.5, 70.5])

        let unsmoothed = WeightTrend.points(weighIns, halfLifeDays: 0)
        #expect(unsmoothed.map(\.trend) == unsmoothed.map(\.kg))
        #expect(WeightTrend.points([:]).isEmpty)
    }

    @Test func changesAreReadFromTheTrend() {
        let points = WeightTrend.points(weighIns)
        let lastDay = firstWeighIn.adding(days: 52)
        // 28 days back is day 24; the last weigh-in by then was on day 21.
        #expect(near(WeightTrend.change(in: points, overDays: 28, endingAt: lastDay), -0.9830187490104976))
        // Between weigh-ins both ends use the weigh-in before them (days 35 and 21).
        let midway = firstWeighIn.adding(days: 40)
        #expect(near(WeightTrend.change(in: points, overDays: 14, endingAt: midway), -0.5694187766440137))
        // The start lies before her first weigh-in.
        #expect(WeightTrend.change(in: points, overDays: 60, endingAt: lastDay) == nil)
        #expect(near(WeightTrend.change(in: points, overDays: 52, endingAt: lastDay), -1.1661849144038285))

        #expect(near(WeightTrend.changeSinceStart(in: points), -1.1661849144038285))
        #expect(WeightTrend.changeSinceStart(in: Array(points.prefix(1))) == nil)
        #expect(WeightTrend.changeSinceStart(in: []) == nil)

        #expect(WeightTrend.trend(on: firstWeighIn.adding(days: -1), in: points) == nil)
        #expect(WeightTrend.trend(on: firstWeighIn, in: points) == 80)
        #expect(near(WeightTrend.trend(on: midway, in: points), 79.24741505796266))
        #expect(WeightTrend.trend(on: firstWeighIn.adding(days: 400), in: points) == points.last?.trend)
    }

    // MARK: - Polish plurals

    @Test(arguments: zip([0, 1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 102, 112],
                         ["0 szklanek", "1 szklanka", "2 szklanki", "4 szklanki", "5 szklanek",
                          "11 szklanek", "12 szklanek", "14 szklanek", "21 szklanek", "22 szklanki",
                          "25 szklanek", "102 szklanki", "112 szklanek"]))
    func glassesInPolish(count: Int, text: String) {
        #expect(PolishPlural.glasses(count) == text)
    }

    @Test func pluralFormOfOtherWords() {
        func weeks(_ count: Int) -> String {
            PolishPlural.form(count, one: "tydzień", few: "tygodnie", many: "tygodni")
        }
        #expect(weeks(1) == "tydzień")
        #expect(weeks(3) == "tygodnie")
        #expect(weeks(13) == "tygodni")
        #expect(weeks(23) == "tygodnie")
        #expect(weeks(101) == "tygodni")
        #expect(weeks(1012) == "tygodni")
        #expect(weeks(-1) == "tydzień")
        #expect(weeks(-2) == "tygodnie")
        #expect(weeks(Int.min) == "tygodni")
        #expect(PolishPlural.days(1) == "1 dzień")
        #expect(PolishPlural.days(22) == "22 dni")
    }
}
