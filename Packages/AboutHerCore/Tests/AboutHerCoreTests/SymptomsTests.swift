import Testing
@testable import AboutHerCore

@Suite("How she felt on a day")
struct SymptomsTests {
    @Test func aScaleIsSetAnywhereFromOneToTenAndCleared() {
        var symptomDay = SymptomDay()
        symptomDay.set(\.energy, to: 7)
        #expect(symptomDay.energy == 7)
        // Another value of the same scale replaces it.
        symptomDay.set(\.energy, to: 3)
        #expect(symptomDay.energy == 3)
        // Values outside 1–10 are kept within it.
        symptomDay.set(\.energy, to: 0)
        #expect(symptomDay.energy == 1)
        symptomDay.set(\.energy, to: 42)
        #expect(symptomDay.energy == 10)
        symptomDay.set(\.energy, to: nil)
        #expect(symptomDay.energy == nil)
        #expect(symptomDay.isEmpty)

        symptomDay.set(\.mood, to: 9)
        symptomDay.set(\.sleep, to: 5)
        symptomDay.set(\.appetite, to: 8)
        #expect(symptomDay == SymptomDay(mood: 9, sleep: 5, appetite: 8))
        // A second tap on the same value still takes it back.
        symptomDay.toggle(\.mood, 9)
        #expect(symptomDay == SymptomDay(sleep: 5, appetite: 8))
    }

    @Test func theInitializerKeepsTheScalesWithinOneToTen() {
        let symptomDay = SymptomDay(energy: -3, mood: 11, sleep: 1, appetite: 10)
        #expect(symptomDay.energy == 1)
        #expect(symptomDay.mood == 10)
        #expect(symptomDay.sleep == 1)
        #expect(symptomDay.appetite == 10)
        #expect(SymptomScale.range == 1...10)
        #expect(SymptomScale.clamped(Int.min) == 1)
        #expect(SymptomScale.clamped(Int.max) == 10)
    }

    @Test func symptomsAreMarkedAndTakenBack() {
        var symptomDay = SymptomDay(mood: 7)
        symptomDay.toggle(SymptomFlag.cramps)
        symptomDay.toggle(SymptomFlag.headache)
        #expect(symptomDay.flags == Set([SymptomFlag.cramps, .headache]))
        symptomDay.toggle(SymptomFlag.cramps)
        #expect(symptomDay.flags == Set([SymptomFlag.headache]))
        // The scales are left as they were.
        #expect(symptomDay.mood == 7)
        symptomDay.toggle(SymptomFlag.headache)
        #expect(symptomDay.flags.isEmpty)
    }

    @Test func aDayTakenBackToNothingIsNotKept() {
        let monday = LocalDate(year: 2026, month: 3, day: 2)
        var appData = AppData()
        var symptomDay = appData.symptoms(on: monday)
        symptomDay.set(\.sleep, to: 8)
        symptomDay.toggle(SymptomFlag.bloating)
        appData.setSymptoms(symptomDay, on: monday)
        #expect(appData.symptoms(on: monday) == SymptomDay(sleep: 8, flags: [.bloating]))

        symptomDay.set(\.sleep, to: nil)
        symptomDay.toggle(SymptomFlag.bloating)
        appData.setSymptoms(symptomDay, on: monday)
        #expect(appData.symptoms.isEmpty)
        #expect(appData.symptoms(on: monday).isEmpty)
    }

    @Test func moodFallsIntoFiveBands() {
        let bands: [MoodLevel] = [.veryLow, .veryLow, .low, .low, .neutral, .neutral, .good, .good, .veryGood, .veryGood]
        for (index, band) in bands.enumerated() {
            #expect(MoodLevel(score: index + 1) == band, "mood \(index + 1)")
        }
        #expect(MoodLevel(score: 0) == .veryLow)
        #expect(MoodLevel(score: 99) == .veryGood)
        // Every word an older file stored lands in its own band again.
        for level in MoodLevel.allCases {
            #expect(MoodLevel(score: level.score) == level)
            #expect(SymptomLegacyWords.mood[level.rawValue] == level.score)
        }
        #expect(SymptomLegacyWords.mood.count == MoodLevel.allCases.count)
    }

    @Test func olderWordsMapOntoTheScaleAsDocumented() {
        #expect(SymptomLegacyWords.energy == ["low": 2, "medium": 5, "high": 8])
        #expect(SymptomLegacyWords.sleep == ["poor": 2, "okay": 5, "good": 8])
        #expect(SymptomLegacyWords.appetite == ["small": 2, "normal": 5, "big": 8])
        #expect(SymptomLegacyWords.mood == ["veryGood": 9, "good": 7, "neutral": 5, "low": 3, "veryLow": 1])
        // Low energy stays low for the movement plan, high stays high.
        #expect(SymptomScale.low.contains(SymptomLegacyWords.energy["low"] ?? 0))
        #expect(SymptomScale.high.contains(SymptomLegacyWords.energy["high"] ?? 0))
        #expect(!SymptomScale.low.contains(5) && !SymptomScale.high.contains(5))
    }
}
