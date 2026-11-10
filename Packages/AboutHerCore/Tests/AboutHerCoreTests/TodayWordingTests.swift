import Testing
@testable import AboutHerCore

@Suite("How the today screen names the day")
struct DayHeadingTests {
    @Test func theGreetingFollowsTheTimeOfDay() {
        #expect(DayHeading.greeting(hour: 5, name: nil) == "dzień dobry")
        #expect(DayHeading.greeting(hour: 12, name: nil) == "dzień dobry")
        #expect(DayHeading.greeting(hour: 17, name: nil) == "dzień dobry")
        #expect(DayHeading.greeting(hour: 18, name: nil) == "dobry wieczór")
        #expect(DayHeading.greeting(hour: 23, name: nil) == "dobry wieczór")
        #expect(DayHeading.greeting(hour: 0, name: nil) == "dobry wieczór")
        #expect(DayHeading.greeting(hour: 4, name: nil) == "dobry wieczór")
        // An hour outside 0–23 never traps; it simply isn't daytime.
        #expect(DayHeading.greeting(hour: -1, name: nil) == "dobry wieczór")
        #expect(DayHeading.greeting(hour: 99, name: nil) == "dobry wieczór")
    }

    @Test func herNameJoinsTheGreetingWhenSheGaveOne() {
        #expect(DayHeading.greeting(hour: 9, name: "Ola") == "dzień dobry, Ola")
        #expect(DayHeading.greeting(hour: 20, name: "  Ola \n") == "dobry wieczór, Ola")
        // A blank name is no name.
        #expect(DayHeading.greeting(hour: 9, name: "   ") == "dzień dobry")
        #expect(DayHeading.greeting(hour: 9, name: "") == "dzień dobry")
    }

    @Test func daysBeforeTodaySayHowLongAgo() {
        let today = LocalDate(year: 2026, month: 3, day: 2)
        #expect(DayHeading.pastDay(today, today: today) == nil)
        #expect(DayHeading.pastDay(today.adding(days: 1), today: today) == nil)
        #expect(DayHeading.pastDay(today.adding(days: -1), today: today) == "wczoraj")
        #expect(DayHeading.pastDay(today.adding(days: -2), today: today) == "przedwczoraj")
        #expect(DayHeading.pastDay(today.adding(days: -3), today: today) == "3 dni temu")
        #expect(DayHeading.pastDay(today.adding(days: -22), today: today) == "22 dni temu")
    }

    @Test func daysAgoAreCountedAcrossMonthsAndYears() {
        let newYear = LocalDate(year: 2027, month: 1, day: 1)
        #expect(DayHeading.pastDay(LocalDate(year: 2026, month: 12, day: 31), today: newYear) == "wczoraj")
        #expect(DayHeading.pastDay(LocalDate(year: 2026, month: 12, day: 22), today: newYear) == "10 dni temu")
        #expect(DayHeading.pastDay(newYear.adding(days: -400), today: newYear) == "400 dni temu")
        // 1 March after a February of 28 days.
        let march = LocalDate(year: 2026, month: 3, day: 1)
        #expect(DayHeading.pastDay(LocalDate(year: 2026, month: 2, day: 27), today: march) == "przedwczoraj")
    }
}

@Suite("A day's marks at a glance")
struct SymptomSummaryTests {
    @Test func countsTheScalesSheMarked() {
        #expect(SymptomDay().markedScaleCount == 0)
        #expect(!SymptomDay().hasEveryScale)
        let three = SymptomDay(energy: 6, mood: 7, sleep: 6, flags: [.bloating])
        #expect(three.markedScaleCount == 3)
        #expect(!three.hasEveryScale)
        var all = three
        all.set(\.appetite, to: 5)
        #expect(all.markedScaleCount == 4)
        #expect(all.hasEveryScale)
        // Clearing one scale takes the day back to three.
        all.set(\.mood, to: nil)
        #expect(all.markedScaleCount == 3)
        #expect(!all.hasEveryScale)
        // Symptoms alone are no scale.
        #expect(SymptomDay(flags: [.cramps, .headache]).markedScaleCount == 0)
    }

    @Test func listsSymptomsInTheAppsOrder() {
        let day = SymptomDay(flags: [.drowsiness, .bloating, .headache])
        #expect(day.orderedFlags == [SymptomFlag.bloating, .headache, .drowsiness])
        #expect(SymptomDay(mood: 4).orderedFlags.isEmpty)
        let everything = SymptomDay(flags: Set(SymptomFlag.allCases))
        #expect(everything.orderedFlags == SymptomFlag.allCases)
    }
}
