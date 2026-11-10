import Foundation
import AboutHerCore

/// Movement: her logged workouts and the stage of her plan.
extension AppStore {
    // MARK: - Reading

    /// Today's suggestion: by her stage, today's phase and the energy she marked today.
    var movementSuggestion: MovementSuggestion {
        WorkoutPlanner.suggestion(stage: data.training.stage,
                                  phase: cycle.phase(on: today, today: today)?.phase,
                                  energy: data.symptoms(on: today).energy)
    }

    /// The stage to offer her today, or nil.
    var trainingStageOffer: Int? {
        WorkoutPlanner.stageOffer(for: data.training, workouts: data.workouts, today: today)
    }

    /// This week, Monday to Sunday.
    var movementWeek: MovementWeek {
        WorkoutPlanner.week(of: today, in: data.workouts)
    }

    /// kcal are counted for 65 kg, because there is no weigh-in and no profile weight.
    var isMovementWeightAssumed: Bool {
        WorkoutEnergy.plausibleWeight(currentWeight) == nil
    }

    /// kcal from the movement she logged on `day`, with her trend or profile weight.
    func movementKcal(on day: LocalDate) -> Double {
        WorkoutEnergy.kcal(data.workouts(on: day), weightKg: currentWeight)
    }

    func movementKcal(_ kind: WorkoutKind, minutes: Int) -> Double {
        WorkoutEnergy.kcal(kind: kind, minutes: minutes, weightKg: currentWeight)
    }

    /// Her daily targets with the day's movement added to the kcal; nil without targets.
    func targetsWithMovement(on day: LocalDate) -> Macros? {
        guard var result = targets else { return nil }
        result.kcal += movementKcal(on: day).rounded()
        return result
    }

    // MARK: - Changes

    /// Logs a workout on `day` (today or earlier). Minutes outside `Workout.minuteRange` are refused.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func logWorkout(_ kind: WorkoutKind, minutes: Int, on day: LocalDate) -> Bool {
        guard Workout.minuteRange.contains(minutes), day <= today else { return false }
        let workout = Workout(kind: kind, minutes: minutes)
        return change { $0.addWorkout(workout, on: day) }
    }

    /// Corrects a logged workout; it keeps its id and its place in the day.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func updateWorkout(_ id: UUID, kind: WorkoutKind, minutes: Int, on day: LocalDate) -> Bool {
        guard Workout.minuteRange.contains(minutes),
              data.workouts(on: day).contains(where: { $0.id == id }) else { return false }
        let workout = Workout(id: id, kind: kind, minutes: minutes)
        return change { $0.updateWorkout(workout, on: day) }
    }

    func removeWorkout(_ id: UUID, on day: LocalDate) {
        change { $0.removeWorkout(id: id, on: day) }
    }

    /// She answered the offer to move up a stage: yes raises it by one (at most to 3), "jeszcze nie"
    /// keeps it. Either way the day is remembered, so the offer doesn't come back too soon.
    @discardableResult
    func answerStageOffer(accepted: Bool) -> Bool {
        let answeredOn = today
        return change { appData in
            if accepted {
                appData.training.stage = Swift.min(appData.training.stage + 1, TrainingProgress.stages.upperBound)
            }
            appData.training.stageOfferAnsweredOn = answeredOn
        }
    }

    /// Sets the stage herself, e.g. back to an easier one; kept within 1–3. A new stage counts as
    /// an answer too, so the offer to move up doesn't come straight back after she went back.
    @discardableResult
    func setTrainingStage(_ stage: Int) -> Bool {
        let stages = TrainingProgress.stages
        let clamped = Swift.min(Swift.max(stage, stages.lowerBound), stages.upperBound)
        let chosenOn = today
        return change { appData in
            guard appData.training.stage != clamped else { return }
            appData.training.stage = clamped
            appData.training.stageOfferAnsweredOn = chosenOn
        }
    }
}
