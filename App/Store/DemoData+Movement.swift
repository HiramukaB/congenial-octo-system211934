import AboutHerCore

extension DemoData {
    /// Made-up movement: a walk today and a few calm workouts on the days before. The plan stays
    /// at its first stage, with too few days for the offer of the next one.
    static func addMovement(to data: inout AppData, today: LocalDate) {
        data.addWorkout(Workout(kind: .walk, minutes: 30), on: today)
        data.addWorkout(Workout(kind: .yoga, minutes: 15), on: today.adding(days: -1))
        data.addWorkout(Workout(kind: .pilates, minutes: 20), on: today.adding(days: -3))
        data.addWorkout(Workout(kind: .walk, minutes: 40), on: today.adding(days: -6))
    }
}
