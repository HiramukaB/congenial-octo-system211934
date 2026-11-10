import Foundation

/// What kind of movement she logged. Raw values are stable keys for her data file; the Polish
/// labels live in the UI.
public enum WorkoutKind: String, Codable, Sendable, CaseIterable {
    case walk           // spacer
    case yoga           // joga
    case stretching     // rozciąganie, mobilność
    case pilates        // pilates
    case strength       // trening siłowy, też z ciężarem ciała
    case intervals      // interwały, HIIT
    case dance          // taniec
    case running        // bieganie
    case cycling        // rower
    case swimming       // pływanie
    case other          // coś innego
}

/// One workout she logged.
public struct Workout: Codable, Sendable, Hashable, Identifiable {
    /// The minutes a workout can have.
    public static let minuteRange: ClosedRange<Int> = 1...600

    public var id: UUID
    public var kind: WorkoutKind
    public var minutes: Int

    public init(id: UUID = UUID(), kind: WorkoutKind, minutes: Int) {
        self.id = id
        self.kind = kind
        self.minutes = minutes
    }
}

/// Where she is with movement: the stage of her plan, raised only when she says yes.
public struct TrainingProgress: Codable, Sendable, Hashable {
    /// 1 = start, 2 = buduj, 3 = pełny rytm.
    public static let stages: ClosedRange<Int> = 1...3

    public var stage: Int
    /// The day she last answered an offer to move up a stage (yes or "not yet") or chose another
    /// stage herself; nil if neither has happened. The next offer waits for it
    /// (`WorkoutPlanner.stageOffer`).
    public var stageOfferAnsweredOn: LocalDate?

    /// A stage outside 1–3 is clamped.
    public init(stage: Int = 1, stageOfferAnsweredOn: LocalDate? = nil) {
        self.stage = Swift.min(Swift.max(stage, TrainingProgress.stages.lowerBound), TrainingProgress.stages.upperBound)
        self.stageOfferAnsweredOn = stageOfferAnsweredOn
    }

    enum CodingKeys: String, CodingKey {
        case stage, stageOfferAnsweredOn
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(stage: try container.decodeIfPresent(Int.self, forKey: .stage) ?? 1,
                  stageOfferAnsweredOn: try container.decodeIfPresent(LocalDate.self, forKey: .stageOfferAnsweredOn))
    }
}

extension AppData {
    /// What she logged on `day`, in the order she logged it.
    public func workouts(on day: LocalDate) -> [Workout] {
        workouts[day] ?? []
    }

    public mutating func addWorkout(_ workout: Workout, on day: LocalDate) {
        workouts[day, default: []].append(workout)
    }

    /// Replaces the workout with the same id on `day`, in its place. Does nothing when there is none.
    public mutating func updateWorkout(_ workout: Workout, on day: LocalDate) {
        guard var entries = workouts[day], let index = entries.firstIndex(where: { $0.id == workout.id }) else { return }
        entries[index] = workout
        workouts[day] = entries
    }

    /// Removes a workout; a day left without any is removed too.
    public mutating func removeWorkout(id: UUID, on day: LocalDate) {
        workouts[day]?.removeAll { $0.id == id }
        if workouts[day]?.isEmpty == true {
            workouts[day] = nil
        }
    }
}
