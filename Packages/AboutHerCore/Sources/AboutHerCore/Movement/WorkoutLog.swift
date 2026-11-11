import Foundation

// MARK: - The list of recent movement

/// A workout with the day she logged it on, for lists that span several days.
public struct DatedWorkout: Sendable, Hashable, Identifiable {
    /// The day and the workout's id together, so two rows never share an id – not even when a
    /// damaged file has one workout on two days.
    public struct Key: Sendable, Hashable {
        public var day: LocalDate
        public var workoutID: UUID
    }

    public var day: LocalDate
    public var workout: Workout

    public init(day: LocalDate, workout: Workout) {
        self.day = day
        self.workout = workout
    }

    public var id: Key {
        Key(day: day, workoutID: workout.id)
    }
}

extension AppData {
    /// Saves `workout` on `day`: the one with the same id is replaced in its place, otherwise it
    /// is added at the end of the day. The movement editor saves every change this way.
    public mutating func saveWorkout(_ workout: Workout, on day: LocalDate) {
        if var entries = workouts[day], let index = entries.firstIndex(where: { $0.id == workout.id }) {
            entries[index] = workout
            workouts[day] = entries
        } else {
            workouts[day, default: []].append(workout)
        }
    }

    /// What she logged on the `days` days up to and including `today`, newest first: the latest
    /// day first and, within a day, the last entry first. Days after `today` are left out, and the
    /// list never reaches back more than a year.
    public func recentWorkouts(through today: LocalDate, days: Int) -> [DatedWorkout] {
        let count = Swift.min(Swift.max(days, 0), 366)
        var result: [DatedWorkout] = []
        for offset in 0..<count {
            let day = today.adding(days: -offset)
            for workout in workouts(on: day).reversed() {
                result.append(DatedWorkout(day: day, workout: workout))
            }
        }
        return result
    }

    /// The minutes of the last `kind` she logged on or before `day`, or nil when there is none.
    /// Minutes outside `Workout.minuteRange` (only a damaged file has them) are passed over.
    public func lastMinutes(of kind: WorkoutKind, through day: LocalDate) -> Int? {
        for date in workouts.keys.filter({ $0 <= day }).sorted(by: >) {
            let match = workouts[date]?.last(where: { workout in
                workout.kind == kind && Workout.minuteRange.contains(workout.minutes)
            })
            if let match {
                return match.minutes
            }
        }
        return nil
    }
}

// MARK: - Minutes on the scale

/// The minutes she sets by dragging in the movement editor: every 5 minutes up to an hour, every
/// 15 up to two hours, every 30 up to four.
public enum WorkoutMinuteSteps {
    public static let values: [Int] = Array(stride(from: 5, through: 60, by: 5)) + [75, 90, 105, 120, 150, 180, 210, 240]

    /// Where a new entry starts when she has never logged its kind.
    public static let defaultMinutes = 30

    /// The index of the step nearest to `minutes`; the lower one when two are equally near.
    public static func nearestIndex(to minutes: Int) -> Int {
        // Kept within the minutes a workout can have, so the distances below can't overflow.
        let target = Swift.min(Swift.max(minutes, Workout.minuteRange.lowerBound), Workout.minuteRange.upperBound)
        var best = 0
        for index in values.indices where abs(values[index] - target) < abs(values[best] - target) {
            best = index
        }
        return best
    }

    /// The minutes of step `index`; an index outside the steps gives the nearest end.
    public static func value(at index: Int) -> Int {
        values[Swift.min(Swift.max(index, 0), values.count - 1)]
    }

    /// The first step above `minutes`, or nil at the top.
    public static func step(above minutes: Int) -> Int? {
        values.first { $0 > minutes }
    }

    /// The last step below `minutes`, or nil at the bottom.
    public static func step(below minutes: Int) -> Int? {
        values.last { $0 < minutes }
    }
}
