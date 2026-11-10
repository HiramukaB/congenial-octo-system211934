import Foundation
import Testing
@testable import AboutHerCore

@Suite("Movement log: the editor's saving, the list of recent movement and the minutes scale")
struct WorkoutLogTests {
    /// A Tuesday; every day and workout here is made up.
    private let today = LocalDate(year: 2026, month: 11, day: 10)

    private func nearest(_ minutes: Int) -> Int {
        WorkoutMinuteSteps.value(at: WorkoutMinuteSteps.nearestIndex(to: minutes))
    }

    // MARK: - Saving

    @Test func aNewWorkoutGoesToTheEndOfItsDay() {
        var data = AppData()
        let walk = Workout(kind: .walk, minutes: 30)
        let yoga = Workout(kind: .yoga, minutes: 15)
        data.saveWorkout(walk, on: today)
        data.saveWorkout(yoga, on: today)
        #expect(data.workouts(on: today) == [walk, yoga])
        #expect(data.workouts.count == 1)
    }

    @Test func savingAgainReplacesTheWorkoutInItsPlace() {
        var data = AppData()
        let walk = Workout(kind: .walk, minutes: 30)
        let yoga = Workout(kind: .yoga, minutes: 15)
        data.saveWorkout(walk, on: today)
        data.saveWorkout(yoga, on: today)
        let corrected = Workout(id: walk.id, kind: .cycling, minutes: 45)
        data.saveWorkout(corrected, on: today)
        #expect(data.workouts(on: today) == [corrected, yoga])
        // Saving it unchanged changes nothing.
        let before = data
        data.saveWorkout(corrected, on: today)
        #expect(data == before)
    }

    @Test func theSameIdOnAnotherDayIsAnotherEntry() {
        var data = AppData()
        let walk = Workout(kind: .walk, minutes: 30)
        data.saveWorkout(walk, on: today)
        data.saveWorkout(walk, on: today.adding(days: -1))
        #expect(data.workouts(on: today) == [walk])
        #expect(data.workouts(on: today.adding(days: -1)) == [walk])
    }

    // MARK: - The list of recent movement

    @Test func recentMovementIsNewestFirstAndStaysInItsDays() {
        var data = AppData()
        let todayWalk = Workout(kind: .walk, minutes: 30)
        let todayYoga = Workout(kind: .yoga, minutes: 15)
        let yesterday = Workout(kind: .dance, minutes: 20)
        let sixDaysAgo = Workout(kind: .swimming, minutes: 40)
        let sevenDaysAgo = Workout(kind: .running, minutes: 25)
        let tomorrow = Workout(kind: .cycling, minutes: 50)
        data.saveWorkout(todayWalk, on: today)
        data.saveWorkout(todayYoga, on: today)
        data.saveWorkout(yesterday, on: today.adding(days: -1))
        data.saveWorkout(sixDaysAgo, on: today.adding(days: -6))
        data.saveWorkout(sevenDaysAgo, on: today.adding(days: -7))
        data.saveWorkout(tomorrow, on: today.adding(days: 1))

        let week = data.recentWorkouts(through: today, days: 7)
        #expect(week.map(\.workout) == [todayYoga, todayWalk, yesterday, sixDaysAgo])
        #expect(week.map(\.day) == [today, today, today.adding(days: -1), today.adding(days: -6)])
        #expect(data.recentWorkouts(through: today, days: 1).map(\.workout) == [todayYoga, todayWalk])
        #expect(data.recentWorkouts(through: today, days: 0).isEmpty)
        #expect(data.recentWorkouts(through: today, days: -3).isEmpty)
        #expect(AppData().recentWorkouts(through: today, days: 7).isEmpty)
        // A huge window stops after a year instead of running for ever.
        #expect(data.recentWorkouts(through: today, days: Int.max).count == 5)
    }

    @Test func everyRowHasItsOwnIdEvenForOneWorkoutOnTwoDays() {
        let walk = Workout(kind: .walk, minutes: 30)
        let first = DatedWorkout(day: today, workout: walk)
        let second = DatedWorkout(day: today.adding(days: -1), workout: walk)
        #expect(first.id != second.id)
        #expect(first.id == DatedWorkout(day: today, workout: walk).id)
    }

    // MARK: - Where a new entry starts

    @Test func aNewEntryStartsFromTheMinutesSheLoggedLast() {
        var data = AppData()
        data.saveWorkout(Workout(kind: .walk, minutes: 40), on: today.adding(days: -9))
        data.saveWorkout(Workout(kind: .walk, minutes: 25), on: today.adding(days: -2))
        data.saveWorkout(Workout(kind: .walk, minutes: 35), on: today.adding(days: -2))
        data.saveWorkout(Workout(kind: .yoga, minutes: 15), on: today)
        data.saveWorkout(Workout(kind: .walk, minutes: 90), on: today.adding(days: 1))
        #expect(data.lastMinutes(of: .walk, through: today) == 35)
        #expect(data.lastMinutes(of: .walk, through: today.adding(days: -3)) == 40)
        #expect(data.lastMinutes(of: .walk, through: today.adding(days: 1)) == 90)
        #expect(data.lastMinutes(of: .yoga, through: today) == 15)
        #expect(data.lastMinutes(of: .dance, through: today) == nil)
        #expect(AppData().lastMinutes(of: .walk, through: today) == nil)
    }

    @Test func minutesFromADamagedFileAreNotOffered() {
        var data = AppData()
        data.saveWorkout(Workout(kind: .walk, minutes: 30), on: today.adding(days: -1))
        data.saveWorkout(Workout(kind: .walk, minutes: 0), on: today)
        data.saveWorkout(Workout(kind: .walk, minutes: 9_000), on: today)
        #expect(data.lastMinutes(of: .walk, through: today) == 30)
    }

    // MARK: - The minutes scale

    @Test func theStepsGrowCalmlyFromFiveMinutesToFourHours() {
        let values = WorkoutMinuteSteps.values
        #expect(values.count == 20)
        #expect(values.first == 5)
        #expect(values.last == 240)
        let isRising = zip(values, values.dropFirst()).allSatisfy { pair in pair.0 < pair.1 }
        #expect(isRising)
        let areRound = values.allSatisfy { Workout.minuteRange.contains($0) && $0 % 5 == 0 }
        #expect(areRound)
        #expect(values.contains(WorkoutMinuteSteps.defaultMinutes))
    }

    @Test func everySuggestedLengthCanBeSetOnTheScale() {
        let phases: [CyclePhase?] = [nil, .menstrual, .follicular, .ovulatory, .luteal]
        let energies: [Int?] = [nil] + (1...10).map { Optional($0) }
        for stage in TrainingProgress.stages {
            for phase in phases {
                for energy in energies {
                    let suggestion = WorkoutPlanner.suggestion(stage: stage, phase: phase, energy: energy)
                    #expect(WorkoutMinuteSteps.values.contains(suggestion.minutes.lowerBound))
                    #expect(WorkoutMinuteSteps.values.contains(suggestion.minutes.upperBound))
                }
            }
        }
    }

    @Test func minutesSnapToTheNearestStepAndTiesGoDown() {
        for value in WorkoutMinuteSteps.values {
            #expect(nearest(value) == value)
        }
        #expect(nearest(32) == 30)
        #expect(nearest(33) == 35)
        #expect(nearest(67) == 60)
        #expect(nearest(68) == 75)
        // 135 is as near to 120 as to 150.
        #expect(nearest(135) == 120)
        #expect(nearest(1) == 5)
        #expect(nearest(600) == 240)
        // Values no editor gives are kept within range instead of trapping.
        #expect(nearest(Int.min) == 5)
        #expect(nearest(Int.max) == 240)
        #expect(WorkoutMinuteSteps.value(at: -4) == 5)
        #expect(WorkoutMinuteSteps.value(at: 99) == 240)
    }

    @Test func voiceOverMovesOneStepFromAnyValue() {
        #expect(WorkoutMinuteSteps.step(above: 30) == 35)
        #expect(WorkoutMinuteSteps.step(above: 37) == 40)
        #expect(WorkoutMinuteSteps.step(above: 60) == 75)
        #expect(WorkoutMinuteSteps.step(above: 1) == 5)
        #expect(WorkoutMinuteSteps.step(above: 240) == nil)
        #expect(WorkoutMinuteSteps.step(below: 30) == 25)
        #expect(WorkoutMinuteSteps.step(below: 37) == 35)
        #expect(WorkoutMinuteSteps.step(below: 600) == 240)
        #expect(WorkoutMinuteSteps.step(below: 5) == nil)
    }
}
