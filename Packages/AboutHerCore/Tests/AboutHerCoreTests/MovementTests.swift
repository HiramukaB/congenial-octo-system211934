import Foundation
import Testing
@testable import AboutHerCore

@Suite("Movement: today's suggestion, kcal, the stage offer and the week")
struct MovementTests {
    /// A Tuesday; every day and workout here is made up.
    private let today = LocalDate(year: 2026, month: 11, day: 10)
    private let phases: [CyclePhase?] = [nil, .menstrual, .follicular, .ovulatory, .luteal]
    private let energies: [EnergyLevel?] = [nil, .low, .medium, .high]

    private func isClose(_ value: Double, _ expected: Double) -> Bool {
        abs(value - expected) < 1e-9
    }

    /// A 20-minute walk on each of the given days before today (0 = today).
    private func walks(daysAgo: [Int]) -> [LocalDate: [Workout]] {
        var workouts: [LocalDate: [Workout]] = [:]
        for offset in daysAgo {
            workouts[today.adding(days: -offset), default: []].append(Workout(kind: .walk, minutes: 20))
        }
        return workouts
    }

    // MARK: - Today's suggestion

    @Test func theFirstStageIsGentleAllCycleLong() {
        for phase in phases {
            for energy in energies {
                let suggestion = WorkoutPlanner.suggestion(stage: 1, phase: phase, energy: energy)
                let expectedVideo: MovementVideo = phase == .menstrual ? .periodYoga : .gentleYoga
                #expect(suggestion.stage == 1)
                #expect(suggestion.focus == .habit)
                #expect(suggestion.kind == .yoga)
                #expect(suggestion.minutes == 10...15)
                #expect(suggestion.video == expectedVideo)
            }
        }
    }

    @Test func theSecondStageBringsBodyweightTrainingButNotOnHardDays() {
        let period = WorkoutPlanner.suggestion(stage: 2, phase: .menstrual, energy: .high)
        #expect(period.focus == .gentle)
        #expect(period.kind == .yoga)
        #expect(period.minutes == 15...15)
        #expect(period.video == .gentleYoga)
        #expect(WorkoutPlanner.suggestion(stage: 2, phase: .ovulatory, energy: .low).focus == .gentle)

        let otherPhases: [CyclePhase?] = [nil, .follicular, .ovulatory, .luteal]
        let otherEnergies: [EnergyLevel?] = [nil, .medium, .high]
        for phase in otherPhases {
            for energy in otherEnergies {
                let suggestion = WorkoutPlanner.suggestion(stage: 2, phase: phase, energy: energy)
                #expect(suggestion.stage == 2)
                #expect(suggestion.focus == .bodyweight)
                #expect(suggestion.kind == .strength)
                #expect(suggestion.minutes == 20...20)
                #expect(suggestion.video == .bodyweight)
            }
        }
    }

    @Test func inTheThirdStageHerEnergyWinsOverTheCalendar() {
        for phase in phases {
            let low = WorkoutPlanner.suggestion(stage: 3, phase: phase, energy: .low)
            #expect(low.focus == .lowEnergy)
            #expect(low.kind == .yoga)
            #expect(low.minutes == 15...15)
            #expect(low.video == .gentleYoga)

            let high = WorkoutPlanner.suggestion(stage: 3, phase: phase, energy: .high)
            #expect(high.focus == .highEnergy)
            #expect(high.minutes == 20...30)
        }
        let rising = WorkoutPlanner.suggestion(stage: 3, phase: .follicular, energy: .high)
        #expect(rising.kind == .intervals)
        #expect(rising.video == .intervals)
        let period = WorkoutPlanner.suggestion(stage: 3, phase: .menstrual, energy: .high)
        #expect(period.kind == .strength)
        #expect(period.video == .bodyweight)
    }

    @Test func inTheThirdStageAnOrdinaryDayFollowsThePhase() {
        let ordinary: [EnergyLevel?] = [nil, .medium]
        for energy in ordinary {
            let period = WorkoutPlanner.suggestion(stage: 3, phase: .menstrual, energy: energy)
            #expect(period.focus == .recovery)
            #expect(period.kind == .yoga)
            #expect(period.minutes == 15...20)
            #expect(period.video == .periodYoga)

            for phase in [CyclePhase.follicular, .ovulatory] {
                let strong = WorkoutPlanner.suggestion(stage: 3, phase: phase, energy: energy)
                #expect(strong.focus == .strength)
                #expect(strong.kind == .strength)
                #expect(strong.minutes == 20...30)
                #expect(strong.video == .strength)
            }

            let calmer: [CyclePhase?] = [.luteal, nil]
            for phase in calmer {
                let moderate = WorkoutPlanner.suggestion(stage: 3, phase: phase, energy: energy)
                #expect(moderate.focus == .moderate)
                #expect(moderate.kind == .strength)
                #expect(moderate.minutes == 20...20)
                #expect(moderate.video == .bodyweight)
            }
        }
    }

    @Test func aStageOutsideTheRangeIsClamped() {
        #expect(WorkoutPlanner.suggestion(stage: 0, phase: .luteal, energy: nil).focus == .habit)
        #expect(WorkoutPlanner.suggestion(stage: -4, phase: nil, energy: .high).stage == 1)
        #expect(WorkoutPlanner.suggestion(stage: 9, phase: .luteal, energy: nil).focus == .moderate)
        #expect(WorkoutPlanner.suggestion(stage: Int.max, phase: nil, energy: nil).stage == 3)
    }

    @Test func theStarLogsTheShorterEndWithinTheAllowedMinutes() {
        for stage in TrainingProgress.stages {
            for phase in phases {
                for energy in energies {
                    let suggestion = WorkoutPlanner.suggestion(stage: stage, phase: phase, energy: energy)
                    #expect(suggestion.loggedMinutes == suggestion.minutes.lowerBound)
                    #expect(Workout.minuteRange.contains(suggestion.loggedMinutes))
                }
            }
        }
    }

    @Test func everyVideoLinkOpensYouTube() {
        for video in MovementVideo.allCases {
            let components = URLComponents(string: video.url)
            #expect(components?.scheme == "https")
            #expect(components?.host == "www.youtube.com")
        }
    }

    // MARK: - kcal

    @Test func kcalAreMETTimesKilogramsTimesHours() {
        #expect(WorkoutKind.walk.met == 3.5)
        #expect(isClose(WorkoutEnergy.kcal(kind: .walk, minutes: 30, weightKg: 70), 122.5))
        #expect(isClose(WorkoutEnergy.kcal(kind: .yoga, minutes: 60, weightKg: 60), 150))
        let day = [Workout(kind: .walk, minutes: 30), Workout(kind: .yoga, minutes: 60)]
        #expect(isClose(WorkoutEnergy.kcal(day, weightKg: 60), 255))
        #expect(WorkoutEnergy.kcal([], weightKg: 60) == 0)
    }

    @Test func withoutAPlausibleWeightTheyAreCountedFor65Kilograms() {
        #expect(WorkoutEnergy.defaultWeightKg == 65)
        #expect(isClose(WorkoutEnergy.kcal(kind: .walk, minutes: 60, weightKg: nil), 227.5))
        let unusable: [Double] = [0, -3, 400, .nan, .infinity]
        for weight in unusable {
            #expect(WorkoutEnergy.plausibleWeight(weight) == nil)
            #expect(isClose(WorkoutEnergy.kcal(kind: .walk, minutes: 60, weightKg: weight), 227.5))
        }
        #expect(WorkoutEnergy.plausibleWeight(64.5) == 64.5)
        #expect(WorkoutEnergy.plausibleWeight(nil) == nil)
    }

    @Test func minutesFromADamagedFileStayWithinRange() {
        #expect(WorkoutEnergy.kcal(kind: .walk, minutes: -20, weightKg: 60) == 0)
        #expect(isClose(WorkoutEnergy.kcal(kind: .walk, minutes: Int.max, weightKg: 60), 3.5 * 60 * 10))
        let monday = today.startOfWeek
        let damaged: [LocalDate: [Workout]] = [
            monday: [Workout(kind: .walk, minutes: Int.max), Workout(kind: .yoga, minutes: Int.max)],
            monday.adding(days: 1): [Workout(kind: .dance, minutes: -5)],
        ]
        #expect(WorkoutPlanner.week(of: monday, in: damaged).minutes == 1200)
    }

    @Test func everyKindHasAPlausibleMET() {
        for kind in WorkoutKind.allCases {
            #expect(kind.met >= 2 && kind.met <= 9)
        }
    }

    // MARK: - The offer to move up a stage

    @Test func theNextStageIsOfferedAfterEightDaysOfMovementInFourWeeks() {
        let start = TrainingProgress()
        let seven = walks(daysAgo: [0, 2, 5, 8, 11, 15, 19])
        let eight = walks(daysAgo: [0, 2, 5, 8, 11, 15, 19, 27])
        #expect(WorkoutPlanner.stageOffer(for: start, workouts: seven, today: today) == nil)
        #expect(WorkoutPlanner.stageOffer(for: start, workouts: eight, today: today) == 2)
        #expect(WorkoutPlanner.stageOffer(for: TrainingProgress(stage: 2), workouts: eight, today: today) == 3)
        #expect(WorkoutPlanner.stageOffer(for: TrainingProgress(stage: 3), workouts: eight, today: today) == nil)

        // 28 days ago is outside the four weeks; tomorrow isn't counted yet.
        let tooOld = walks(daysAgo: [0, 2, 5, 8, 11, 15, 19, 28])
        #expect(WorkoutPlanner.stageOffer(for: start, workouts: tooOld, today: today) == nil)
        let withTomorrow = walks(daysAgo: [-1, 0, 2, 5, 8, 11, 15, 19])
        #expect(WorkoutPlanner.stageOffer(for: start, workouts: withTomorrow, today: today) == nil)
        // Two workouts on one day are one day of movement.
        let twiceToday = walks(daysAgo: [0, 0, 2, 5, 8, 11, 15, 19])
        #expect(WorkoutPlanner.stageOffer(for: start, workouts: twiceToday, today: today) == nil)
        #expect(WorkoutPlanner.activeDays(in: twiceToday, from: today.adding(days: -27), through: today) == 7)
    }

    @Test func afterAnAnswerTheOfferWaitsAndCountsOnlyTheDaysSince() {
        let everyDay = walks(daysAgo: Array(0..<28))
        let thirteenDaysAgo = TrainingProgress(stage: 1, stageOfferAnsweredOn: today.adding(days: -13))
        #expect(WorkoutPlanner.stageOffer(for: thirteenDaysAgo, workouts: everyDay, today: today) == nil)
        let fourteenDaysAgo = TrainingProgress(stage: 1, stageOfferAnsweredOn: today.adding(days: -14))
        #expect(WorkoutPlanner.stageOffer(for: fourteenDaysAgo, workouts: everyDay, today: today) == 2)

        // Seven days of movement after the answer; the answer day and the days before it don't count.
        let mostlyBefore = walks(daysAgo: [0, 2, 4, 6, 8, 10, 12, 14, 15, 16, 17, 18, 19, 20])
        #expect(WorkoutPlanner.stageOffer(for: fourteenDaysAgo, workouts: mostlyBefore, today: today) == nil)
        let oneMore = walks(daysAgo: [0, 1, 2, 4, 6, 8, 10, 12, 14, 15, 16])
        #expect(WorkoutPlanner.stageOffer(for: fourteenDaysAgo, workouts: oneMore, today: today) == 2)

        // An answer "in the future" (a changed clock) keeps it quiet.
        let future = TrainingProgress(stage: 1, stageOfferAnsweredOn: today.adding(days: 3))
        #expect(WorkoutPlanner.stageOffer(for: future, workouts: everyDay, today: today) == nil)
    }

    // MARK: - The week

    @Test func theWeekRunsFromMondayToSundayAndCountsDays() {
        let monday = LocalDate(year: 2026, month: 11, day: 9)
        #expect(monday.isoWeekday == 1)
        let workouts: [LocalDate: [Workout]] = [
            monday.adding(days: -1): [Workout(kind: .walk, minutes: 60)],
            monday: [Workout(kind: .yoga, minutes: 15)],
            monday.adding(days: 2): [Workout(kind: .walk, minutes: 30), Workout(kind: .dance, minutes: 20)],
            monday.adding(days: 6): [Workout(kind: .swimming, minutes: 40)],
            monday.adding(days: 7): [Workout(kind: .running, minutes: 25)],
        ]
        let expected = MovementWeek(monday: monday,
                                    activeDays: [monday, monday.adding(days: 2), monday.adding(days: 6)],
                                    workoutCount: 4,
                                    minutes: 105)
        #expect(WorkoutPlanner.week(of: monday.adding(days: 3), in: workouts) == expected)
        #expect(WorkoutPlanner.week(of: monday.adding(days: 6), in: workouts) == expected)
        #expect(WorkoutPlanner.week(of: monday.adding(days: 7), in: workouts).activeDays == Set([monday.adding(days: 7)]))
        #expect(WorkoutPlanner.week(of: monday, in: [:]) == MovementWeek(monday: monday))
    }
}
