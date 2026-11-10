import Foundation
import AboutHerCore

/// What the movement editor needs from the store. Kept next to the editor; it changes her data only
/// through `change`, like every other feature.
extension AppStore {
    /// Saves a workout from the editor at once: one she logged before is replaced in its place, a
    /// new one is added to `day` (today or earlier). Minutes outside `Workout.minuteRange` are
    /// refused. Returns `false` when nothing was saved.
    @discardableResult
    func saveWorkout(_ workout: Workout, on day: LocalDate) -> Bool {
        guard Workout.minuteRange.contains(workout.minutes) else { return false }
        let isLogged = data.workouts(on: day).contains { $0.id == workout.id }
        guard isLogged || day <= today else { return false }
        return change { $0.saveWorkout(workout, on: day) }
    }

    /// The minutes a new entry of `kind` starts with: what she logged for it last time, or 30.
    func suggestedMinutes(for kind: WorkoutKind) -> Int {
        data.lastMinutes(of: kind, through: today) ?? WorkoutMinuteSteps.defaultMinutes
    }
}
