import Foundation
import AboutHerCore

/// A fictional, fairly regular history for screenshots – never her real data.
enum DemoData {
    static func make(today: LocalDate) -> AppData {
        var days = Set<LocalDate>()
        for startOffset in [-109, -78, -47, -16] {
            let start = today.adding(days: startOffset)
            for day in 0..<5 {
                days.insert(start.adding(days: day))
            }
        }
        var data = AppData(periodDays: days)

        // A made-up person: not her height, weight or age.
        data.nutritionProfile = NutritionProfile(birthYear: today.year - 34, heightCm: 168, weightKg: 66,
                                                 activity: .light, deficitKcal: 250)
        let weights: [Double] = [66.2, 65.9, 66.1, 65.6, 65.7, 65.2, 65.0, 64.8]
        for (index, kg) in weights.enumerated() {
            data.setWeight(kg, on: today.adding(days: (index - weights.count + 1) * 7))
        }

        let parser = MealParser(catalog: .builtIn)
        let meals = [
            "owsianka z bananem i łyżką masła orzechowego",
            "2 kromki chleba żytniego z twarożkiem i rzodkiewką",
            "zupa pomidorowa z ryżem",
        ]
        for text in meals {
            data.addMeal(MealEntry(text: text, parsed: parser.parse(text)), on: today)
        }
        data.addMeal(MealEntry(text: "jajecznica z trzech jajek i pomidor", parsed: parser.parse("jajecznica z trzech jajek i pomidor")),
                     on: today.adding(days: -1))
        data.addWater(2, to: .morning, on: today)
        data.addWater(2, to: .midday, on: today)

        // One part of the app each, every one in its own file (DemoData+….swift).
        let now = Date.now
        addSymptoms(to: &data, today: today)
        addSettings(to: &data, today: today)
        addOnboarding(to: &data, now: now)
        addMovement(to: &data, today: today)
        addInner(to: &data, today: today)
        addMoment(to: &data, today: today)
        addHumor(to: &data, now: now)
        return data
    }
}
