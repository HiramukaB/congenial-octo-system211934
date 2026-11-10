import Testing
@testable import AboutHerCore

@Suite("How she felt on a day")
struct SymptomsTests {
    @Test func aSecondTapOnTheSameValueTakesItBack() {
        var symptomDay = SymptomDay()
        symptomDay.toggle(\.energy, EnergyLevel.low)
        #expect(symptomDay.energy == EnergyLevel.low)
        // Another value of the same scale replaces it.
        symptomDay.toggle(\.energy, EnergyLevel.high)
        #expect(symptomDay.energy == EnergyLevel.high)
        symptomDay.toggle(\.energy, EnergyLevel.high)
        #expect(symptomDay.energy == nil)
        #expect(symptomDay.isEmpty)

        symptomDay.toggle(\.mood, MoodLevel.veryGood)
        symptomDay.toggle(\.sleep, SleepQuality.okay)
        symptomDay.toggle(\.appetite, AppetiteLevel.big)
        #expect(symptomDay == SymptomDay(mood: .veryGood, sleep: .okay, appetite: .big))
        symptomDay.toggle(\.mood, MoodLevel.veryGood)
        #expect(symptomDay == SymptomDay(sleep: .okay, appetite: .big))
    }

    @Test func symptomsAreMarkedAndTakenBack() {
        var symptomDay = SymptomDay(mood: .good)
        symptomDay.toggle(SymptomFlag.cramps)
        symptomDay.toggle(SymptomFlag.headache)
        #expect(symptomDay.flags == Set([SymptomFlag.cramps, .headache]))
        symptomDay.toggle(SymptomFlag.cramps)
        #expect(symptomDay.flags == Set([SymptomFlag.headache]))
        // The scales are left as they were.
        #expect(symptomDay.mood == MoodLevel.good)
        symptomDay.toggle(SymptomFlag.headache)
        #expect(symptomDay.flags.isEmpty)
    }

    @Test func aDayTakenBackToNothingIsNotKept() {
        let monday = LocalDate(year: 2026, month: 3, day: 2)
        var appData = AppData()
        var symptomDay = appData.symptoms(on: monday)
        symptomDay.toggle(\.sleep, SleepQuality.good)
        symptomDay.toggle(SymptomFlag.bloating)
        appData.setSymptoms(symptomDay, on: monday)
        #expect(appData.symptoms(on: monday) == SymptomDay(sleep: .good, flags: [.bloating]))

        symptomDay.toggle(\.sleep, SleepQuality.good)
        symptomDay.toggle(SymptomFlag.bloating)
        appData.setSymptoms(symptomDay, on: monday)
        #expect(appData.symptoms.isEmpty)
        #expect(appData.symptoms(on: monday).isEmpty)
    }
}
