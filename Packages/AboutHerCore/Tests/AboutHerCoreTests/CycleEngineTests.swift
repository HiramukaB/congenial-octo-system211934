import Testing
@testable import AboutHerCore

/// A fictional history: a period of `bleed` days at the start of every cycle,
/// plus one more period after the last cycle.
func history(from first: LocalDate, cycles: [Int], bleed: Int = 6) -> (days: Set<LocalDate>, lastStart: LocalDate) {
    var days = Set<LocalDate>()
    var start = first
    for length in cycles {
        for offset in 0..<bleed { days.insert(start.adding(days: offset)) }
        start = start.adding(days: length)
    }
    for offset in 0..<bleed { days.insert(start.adding(days: offset)) }
    return (days, start)
}

@Suite("Cycle engine")
struct CycleEngineTests {
    let first = LocalDate(year: 2025, month: 1, day: 10)
    let irregular = [41, 31, 37, 47]
    let regular = [28, 28, 29, 28]

    @Test func groupsDaysIntoPeriodsAndBridgesShortGaps() {
        let day = LocalDate(year: 2025, month: 3, day: 1)
        let marked: Set<LocalDate> = [day, day.adding(days: 1), day.adding(days: 2), day.adding(days: 4),
                                      day.adding(days: 30), day.adding(days: 31)]
        let periods = CycleMath.periods(from: marked)
        #expect(periods.count == 2)
        #expect(periods[0] == PeriodRange(start: day, end: day.adding(days: 4)))
        #expect(periods[1].length == 2)
    }

    @Test func irregularHistoryStatistics() {
        let stats = CycleEngine(periodDays: history(from: first, cycles: irregular).days).stats
        #expect(stats.cycleLengths == [41, 31, 37, 47])
        #expect(stats.typicalCycleLength == 39)
        #expect(stats.shortestCycle == 31)
        #expect(stats.longestCycle == 47)
        #expect(stats.variability == 16)
        #expect(stats.isIrregular)
        #expect(stats.confidence == .low)
        #expect(stats.typicalPeriodLength == 6)
    }

    @Test func implausibleGapsAreNotCountedAsCycles() {
        let stats = CycleEngine(periodDays: history(from: first, cycles: [30, 140, 31]).days).stats
        #expect(stats.cycleLengths == [30, 31])
    }

    @Test func staleHistoryIsNotReportedAsADayOfTheCycle() {
        // The web version showed "day 102, luteal phase" in exactly this situation.
        let h = history(from: first, cycles: irregular)
        let status = CycleEngine(periodDays: h.days).status(on: h.lastStart.adding(days: 101))
        #expect(status.state == .stale(daysSinceLastPeriod: 101))
        #expect(status.prediction == nil)
    }

    @Test func predictionWindowFollowsHerSpread() {
        let h = history(from: first, cycles: irregular)
        let engine = CycleEngine(periodDays: h.days)
        let prediction = engine.nextPeriod(after: engine.periods[engine.periods.count - 1])
        #expect(prediction.expected == h.lastStart.adding(days: 39))
        #expect(prediction.earliest == h.lastStart.adding(days: 31))
        #expect(prediction.latest == h.lastStart.adding(days: 47))
    }

    @Test func latePeriodIsCountedFromTheExpectedDate() {
        let h = history(from: first, cycles: irregular)
        let status = CycleEngine(periodDays: h.days).status(on: h.lastStart.adding(days: 50))
        #expect(status.state == .late(daysLate: 11))
    }

    @Test func noGuessingPastTheWindowWhenLate() {
        let h = history(from: first, cycles: irregular)
        let engine = CycleEngine(periodDays: h.days)
        let today = h.lastStart.adding(days: 50)
        #expect(engine.phase(on: today.adding(days: 3), today: today) == nil)
        #expect(engine.phase(on: h.lastStart.adding(days: 48), today: today) == nil)
        #expect(engine.phase(on: h.lastStart.adding(days: 40), today: today)?.phase == .luteal)
    }

    @Test func irregularMidCycleIsALowConfidenceGuess() {
        let h = history(from: first, cycles: irregular)
        let engine = CycleEngine(periodDays: h.days)
        let today = h.lastStart.adding(days: 24)
        guard case .active(let info) = engine.status(on: today).state else {
            Issue.record("expected an active cycle")
            return
        }
        #expect(info.cycleDay == 25)
        #expect(info.phase == .ovulatory)
        #expect(info.confidence == .low)

        let early = engine.phase(on: h.lastStart.adding(days: 9), today: today)
        #expect(early?.phase == .follicular)
        #expect(early?.confidence == .medium)
    }

    @Test func regularCycleIsConfident() {
        let h = history(from: first, cycles: regular, bleed: 5)
        let engine = CycleEngine(periodDays: h.days)
        #expect(engine.stats.typicalCycleLength == 28)
        #expect(engine.stats.confidence == .high)

        let today = h.lastStart.adding(days: 13)
        #expect(engine.phase(on: today, today: today) ==
                PhaseInfo(phase: .ovulatory, cycleDay: 14, confidence: .high, isLoggedPeriod: false, isPrediction: false))
        #expect(engine.phase(on: h.lastStart.adding(days: 7), today: today)?.phase == .follicular)
        #expect(engine.phase(on: h.lastStart.adding(days: 21), today: today)?.phase == .luteal)

        let prediction = engine.nextPeriod(after: engine.periods[engine.periods.count - 1])
        #expect(prediction.earliest == h.lastStart.adding(days: 26))
        #expect(prediction.latest == h.lastStart.adding(days: 30))
    }

    @Test func futurePeriodsAreProjectedAsPredictions() {
        let h = history(from: first, cycles: regular, bleed: 5)
        let engine = CycleEngine(periodDays: h.days)
        let today = h.lastStart.adding(days: 10)
        let projected = engine.phase(on: h.lastStart.adding(days: 30), today: today)
        #expect(projected?.phase == .menstrual)
        #expect(projected?.cycleDay == 3)
        #expect(projected?.isPrediction == true)
        #expect(projected?.isLoggedPeriod == false)
    }

    @Test func finishedCyclesAreReadBackwardsFromTheNextPeriod() {
        let h = history(from: first, cycles: irregular)
        let engine = CycleEngine(periodDays: h.days)
        let today = h.lastStart
        // The first cycle lasted 41 days, so ovulation was around day 28.
        #expect(engine.phase(on: first.adding(days: 19), today: today)?.phase == .follicular)
        #expect(engine.phase(on: first.adding(days: 27), today: today)?.phase == .ovulatory)
        #expect(engine.phase(on: first.adding(days: 33), today: today)?.phase == .luteal)
        #expect(engine.phase(on: first.adding(days: 33), today: today)?.confidence == .medium)
    }

    @Test func noPeriodsMeansNoData() {
        let engine = CycleEngine(periodDays: Set<LocalDate>())
        #expect(engine.status(on: first).state == .noData)
        #expect(engine.phase(on: first, today: first) == nil)
    }

    @Test func aSinglePeriodUsesTextbookDefaults() {
        let h = history(from: first, cycles: [], bleed: 5)
        let engine = CycleEngine(periodDays: h.days)
        guard case .active(let info) = engine.status(on: first.adding(days: 9)).state else {
            Issue.record("expected an active cycle")
            return
        }
        #expect(info.phase == .follicular)
        #expect(info.confidence == .medium)
        #expect(engine.nextPeriod(after: engine.periods[0]).expected == first.adding(days: 28))
    }

    @Test func bleedingTodayIsALoggedPeriod() {
        let h = history(from: first, cycles: [30, 30], bleed: 5)
        let engine = CycleEngine(periodDays: h.days)
        guard case .active(let info) = engine.status(on: h.lastStart.adding(days: 2)).state else {
            Issue.record("expected an active cycle")
            return
        }
        #expect(info.phase == .menstrual)
        #expect(info.isLoggedPeriod)
        #expect(info.cycleDay == 3)
    }

    // MARK: - Spotting, unmarked period days, the first cycle

    @Test func aLoneSpottingDayDoesNotStartACycle() {
        let h = history(from: first, cycles: regular, bleed: 5)
        let spotting = h.lastStart.adding(days: 16)            // cycle day 17
        let today = h.lastStart.adding(days: 19)               // cycle day 20
        let engine = CycleEngine(periodDays: h.days.union([spotting]), today: today)
        #expect(engine.stats.cycleLengths == regular)
        #expect(engine.periods.last?.start == h.lastStart)
        #expect(engine.status(on: today).cycleDay == 20)
        // The marked day itself still reads as bleeding, inside the running cycle.
        #expect(engine.phase(on: spotting, today: today)?.isLoggedPeriod == true)
        #expect(engine.phase(on: spotting, today: today)?.cycleDay == 17)
    }

    @Test func aDayMarkedTodayCountsAsDayOneUntilItTurnsOutToBeSpotting() {
        let h = history(from: first, cycles: regular, bleed: 5)
        let marked = h.lastStart.adding(days: 16)
        let days = h.days.union([marked])
        #expect(CycleEngine(periodDays: days, today: marked).status(on: marked).cycleDay == 1)
        let nextDay = marked.adding(days: 1)
        #expect(CycleEngine(periodDays: days, today: nextDay).status(on: nextDay).cycleDay == 2)
        let twoDaysLater = marked.adding(days: 2)
        #expect(CycleEngine(periodDays: days, today: twoDaysLater).status(on: twoDaysLater).cycleDay == 19)
    }

    @Test func spottingJustBeforeAPeriodDoesNotMoveTheCycleStart() {
        let h = history(from: first, cycles: [26, 30], bleed: 5)
        let engine = CycleEngine(periodDays: h.days.union([h.lastStart.adding(days: -4)]))
        #expect(engine.periods.last?.start == h.lastStart)
        #expect(engine.stats.cycleLengths == [26, 30])
    }

    @Test func anUnmarkedDayWithinHerUsualPeriodLengthIsProbablyStillPeriod() {
        let h = history(from: first, cycles: regular, bleed: 5)
        var days = h.days
        // Of the newest period only the first day is marked so far.
        for offset in 1..<5 { days.remove(h.lastStart.adding(days: offset)) }
        let today = h.lastStart.adding(days: 2)                // day 3
        let engine = CycleEngine(periodDays: days, today: today)
        let info = engine.phase(on: today, today: today)
        #expect(info?.phase == .menstrual)
        #expect(info?.isLoggedPeriod == false)
        #expect(info?.confidence == .medium)
        #expect(engine.phase(on: h.lastStart.adding(days: 4), today: today)?.phase == .menstrual)
        #expect(engine.phase(on: h.lastStart.adding(days: 6), today: today)?.phase == .follicular)
        // Days she has already lived through without marking them were not period days.
        let later = h.lastStart.adding(days: 6)
        #expect(engine.phase(on: h.lastStart.adding(days: 2), today: later)?.phase == .follicular)
    }

    @Test func withOnlyOnePeriodTheAppNeverSaysLate() {
        let engine = CycleEngine(periodDays: history(from: first, cycles: [], bleed: 5).days)
        let prediction = engine.nextPeriod(after: engine.periods[0])
        #expect(prediction.earliest == first.adding(days: 21))
        #expect(prediction.latest == first.adding(days: 35))

        let today = first.adding(days: 39)                     // day 40, past a textbook 28 ± 7
        let status = engine.status(on: today)
        guard case .active(let info) = status.state else {
            Issue.record("expected an active cycle")
            return
        }
        #expect(info.cycleDay == 40)
        #expect(status.prediction == nil)
        #expect(engine.phase(on: today.adding(days: 1), today: today) == nil)
    }

    @Test func cycleDayIsKnownEvenWhereThePhaseIsNot() {
        let h = history(from: first, cycles: irregular)
        let engine = CycleEngine(periodDays: h.days)
        let today = h.lastStart.adding(days: 60)
        #expect(engine.phase(on: h.lastStart.adding(days: 55), today: today) == nil)
        #expect(engine.cycleDay(on: h.lastStart.adding(days: 55)) == 56)
        #expect(engine.cycleDay(on: h.lastStart.adding(days: 95)) == nil)
        #expect(engine.cycleDay(on: first.adding(days: -1)) == nil)

        let gap = history(from: first, cycles: [30, 140, 31])
        #expect(CycleEngine(periodDays: gap.days).cycleDay(on: first.adding(days: 100)) == nil)
    }
}
