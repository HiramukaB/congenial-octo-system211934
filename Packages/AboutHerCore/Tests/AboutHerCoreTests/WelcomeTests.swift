import Foundation
import Testing
@testable import AboutHerCore

// The welcome steps: reading the numbers she types and marking a period in one go.
// Every number and date here is made up.
@Suite("Welcome")
struct WelcomeTests {
    private let today = LocalDate(year: 2026, month: 11, day: 10)

    private func day(_ number: Int, month: Int = 11) -> LocalDate {
        LocalDate(year: 2026, month: month, day: number)
    }

    // MARK: - Numbers

    @Test func numbersWithACommaOrAPoint() {
        #expect(BodyNumbers.number("64,5") == 64.5)
        #expect(BodyNumbers.number("64.5") == 64.5)
        #expect(BodyNumbers.number(" 70 ") == 70)
        #expect(BodyNumbers.number("") == nil)
        #expect(BodyNumbers.number("   ") == nil)
        #expect(BodyNumbers.number("sześćdziesiąt") == nil)
        #expect(BodyNumbers.number("6 4") == nil)
        #expect(BodyNumbers.number("nan") == nil)
        #expect(BodyNumbers.number("inf") == nil)
        #expect(BodyNumbers.number("1e400") == nil)
    }

    @Test func birthYearInFull() {
        #expect(BodyNumbers.birthYear("1995", currentYear: 2026) == 1995)
        #expect(BodyNumbers.birthYear(" 1990 ", currentYear: 2026) == 1990)
        #expect(BodyNumbers.birthYear("1920", currentYear: 2026) == 1920)
        #expect(BodyNumbers.birthYear("2016", currentYear: 2026) == 2016)
        // Two digits, too early, too late, not a whole year.
        #expect(BodyNumbers.birthYear("95", currentYear: 2026) == nil)
        #expect(BodyNumbers.birthYear("1919", currentYear: 2026) == nil)
        #expect(BodyNumbers.birthYear("2017", currentYear: 2026) == nil)
        #expect(BodyNumbers.birthYear("1995,5", currentYear: 2026) == nil)
        #expect(BodyNumbers.birthYear("", currentYear: 2026) == nil)
    }

    @Test func heightInCentimetresOrMetres() {
        #expect(BodyNumbers.heightCm("165") == 165)
        #expect(BodyNumbers.heightCm("165,5") == 165.5)
        #expect(BodyNumbers.heightCm("1,65") == 165)
        #expect(BodyNumbers.heightCm("1.7") == 170)
        #expect(BodyNumbers.heightCm("2,2") == 220)
        #expect(BodyNumbers.heightCm("120") == 120)
        #expect(BodyNumbers.heightCm("119") == nil)
        #expect(BodyNumbers.heightCm("221") == nil)
        #expect(BodyNumbers.heightCm("17") == nil)
        #expect(BodyNumbers.heightCm("") == nil)
    }

    @Test func weightInKilograms() {
        #expect(BodyNumbers.weightKg("64,5") == 64.5)
        #expect(BodyNumbers.weightKg("25") == 25)
        #expect(BodyNumbers.weightKg("250") == 250)
        #expect(BodyNumbers.weightKg("24,9") == nil)
        #expect(BodyNumbers.weightKg("251") == nil)
        #expect(BodyNumbers.weightKg("6") == nil)
    }

    @Test func ownTargetsNeedAllFour() {
        #expect(BodyNumbers.ownTargets(kcal: "1600", protein: "100", carbs: "180", fat: "55")
                == Macros(kcal: 1600, protein: 100, carbs: 180, fat: 55))
        #expect(BodyNumbers.ownTargets(kcal: "1600", protein: "0", carbs: "12,5", fat: "55")
                == Macros(kcal: 1600, protein: 0, carbs: 12.5, fat: 55))
        // A missing field, a kcal typo, a negative gram value.
        #expect(BodyNumbers.ownTargets(kcal: "1600", protein: "", carbs: "180", fat: "55") == nil)
        #expect(BodyNumbers.ownTargets(kcal: "160", protein: "100", carbs: "180", fat: "55") == nil)
        #expect(BodyNumbers.ownTargets(kcal: "16000", protein: "100", carbs: "180", fat: "55") == nil)
        #expect(BodyNumbers.ownTargets(kcal: "1600", protein: "-1", carbs: "180", fat: "55") == nil)
        #expect(BodyNumbers.dailyKcal("800") == 800)
        #expect(BodyNumbers.dailyKcal("4000") == 4000)
        #expect(BodyNumbers.dailyKcal("799") == nil)
    }

    @Test func valuesGoBackIntoAFieldTheWayTheyAreRead() {
        #expect(BodyNumbers.text(64.5) == "64,5")
        #expect(BodyNumbers.text(165) == "165")
        #expect(BodyNumbers.text(100) == "100")
        #expect(BodyNumbers.text(64.25) == "64,25")
        #expect(BodyNumbers.text(1.1) == "1,1")
        #expect(BodyNumbers.text(0.05) == "0,05")
        #expect(BodyNumbers.text(64.504) == "64,5")
        #expect(BodyNumbers.text(-5) == "-5")
        #expect(BodyNumbers.text(1e300) == "1000000000000")
        #expect(BodyNumbers.text(0) == "0")
        #expect(BodyNumbers.text(-0.001) == "0")
        #expect(BodyNumbers.text(.nan) == "0")
        #expect(BodyNumbers.text(.infinity) == "0")
        for value in [64.5, 165.0, 1600.0, 12.75] {
            #expect(BodyNumbers.number(BodyNumbers.text(value)) == value)
        }
    }

    @Test func wholeNumbersNeverTrap() {
        #expect(BodyNumbers.whole(1633.6) == 1634)
        #expect(BodyNumbers.whole(.nan) == 0)
        #expect(BodyNumbers.whole(.infinity) == 0)
        #expect(BodyNumbers.whole(1e300) == 1_000_000_000_000_000)
        #expect(BodyNumbers.whole(-1e300) == -1_000_000_000_000_000)
    }

    // MARK: - Marking a period

    @Test func marksThePeriodUpToToday() {
        var data = AppData()
        let added = data.markPeriodDays(from: day(3), count: 5, today: today)
        #expect(added == Set((3...7).map { day($0) }))
        #expect(data.periodDays == added)

        // Started two days ago: only the days until today, never a day ahead.
        var recent = AppData()
        let recentAdded = recent.markPeriodDays(from: day(8), count: 5, today: today)
        #expect(recentAdded == [day(8), day(9), day(10)])
        #expect(recent.periodDays == recentAdded)
    }

    @Test func aCorrectedAnswerLeavesNothingBehind() {
        var data = AppData()
        let first = data.markPeriodDays(from: day(1), count: 5, today: today)
        let second = data.markPeriodDays(from: day(3), count: 4, today: today, replacing: first)
        #expect(data.periodDays == Set((3...6).map { day($0) }))
        #expect(second == data.periodDays)

        // A shorter period on the same day.
        let third = data.markPeriodDays(from: day(3), count: 2, today: today, replacing: second)
        #expect(data.periodDays == [day(3), day(4)])
        #expect(third == [day(3), day(4)])

        // No answer any more: everything the answers marked goes.
        let none = data.markPeriodDays(from: nil, count: 5, today: today, replacing: third)
        #expect(none.isEmpty)
        #expect(data.periodDays.isEmpty)
    }

    @Test func daysSheMarkedHerselfStay() {
        var data = AppData(periodDays: [day(2), day(20, month: 10)])
        let added = data.markPeriodDays(from: day(1), count: 3, today: today)
        // 2 November was hers already, so it isn't the answer's to take back.
        #expect(added == [day(1), day(3)])
        #expect(data.periodDays == [day(1), day(2), day(3), day(20, month: 10)])

        let moved = data.markPeriodDays(from: day(5), count: 2, today: today, replacing: added)
        #expect(moved == [day(5), day(6)])
        #expect(data.periodDays == [day(2), day(5), day(6), day(20, month: 10)])
    }

    @Test func oddAnswersOnlyTakeBack() {
        var data = AppData()
        let added = data.markPeriodDays(from: day(4), count: 3, today: today)

        // A start after today marks nothing, but the earlier answer still goes.
        var future = data
        let futureAdded = future.markPeriodDays(from: day(12), count: 3, today: today, replacing: added)
        #expect(futureAdded.isEmpty)
        #expect(future.periodDays.isEmpty)

        var zero = data
        let zeroAdded = zero.markPeriodDays(from: day(4), count: 0, today: today, replacing: added)
        #expect(zeroAdded.isEmpty)
        #expect(zero.periodDays.isEmpty)

        // At most two weeks in one answer.
        var long = AppData()
        let longAdded = long.markPeriodDays(from: day(1, month: 10), count: 40, today: today)
        #expect(longAdded.count == AppData.longestMarkedPeriod)
        #expect(longAdded.contains(day(14, month: 10)))
        #expect(!longAdded.contains(day(15, month: 10)))
    }

    @Test func aMarkedPeriodReadsAsOneInTheCycle() {
        var data = AppData()
        data.markPeriodDays(from: day(3), count: 5, today: today)
        let engine = CycleEngine(periodDays: data.periodDays, today: today)
        #expect(engine.periods == [PeriodRange(start: day(3), end: day(7))])
        #expect(engine.status(on: today).cycleDay == 8)
    }
}
