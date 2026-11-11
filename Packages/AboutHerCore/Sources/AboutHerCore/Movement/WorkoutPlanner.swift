import Foundation

// MARK: - Energy

extension WorkoutKind {
    /// A rough MET value at an easy to moderate pace, after the Compendium of Physical Activities:
    /// how many times her resting energy the activity takes.
    public var met: Double {
        switch self {
        case .walk: 3.5
        case .yoga: 2.5
        case .stretching: 2.3
        case .pilates: 3.0
        case .strength: 3.5
        case .intervals: 7.0
        case .dance: 5.0
        case .running: 8.0
        case .cycling: 6.0
        case .swimming: 6.0
        case .other: 3.5
        }
    }
}

/// kcal from movement: MET × kg × hours. Always an estimate, and the app says "ok." with it.
public enum WorkoutEnergy {
    /// Used while the app knows nothing about her weight.
    public static let defaultWeightKg: Double = 65
    /// The weights the app accepts for a weigh-in; anything else counts as unknown.
    static let plausibleWeights: ClosedRange<Double> = 25...250

    /// Her weight when it is one a person can have (25–250 kg); nil otherwise.
    public static func plausibleWeight(_ weightKg: Double?) -> Double? {
        guard let weightKg, weightKg.isFinite, plausibleWeights.contains(weightKg) else { return nil }
        return weightKg
    }

    /// Minutes outside `Workout.minuteRange` (only a damaged file has them) are kept within 0–600.
    public static func kcal(kind: WorkoutKind, minutes: Int, weightKg: Double?) -> Double {
        let kilograms = plausibleWeight(weightKg) ?? defaultWeightKg
        let clampedMinutes = Swift.min(Swift.max(0, minutes), Workout.minuteRange.upperBound)
        return kind.met * kilograms * Double(clampedMinutes) / 60
    }

    public static func kcal(_ workouts: [Workout], weightKg: Double?) -> Double {
        workouts.reduce(0) { total, workout in
            total + kcal(kind: workout.kind, minutes: workout.minutes, weightKg: weightKg)
        }
    }
}

// MARK: - Today's suggestion

/// A video the suggestion links to; the app opens it in YouTube, or in Safari without the app.
public enum MovementVideo: String, Sendable, CaseIterable {
    case gentleYoga, periodYoga, strength, intervals, bodyweight

    public var url: String {
        switch self {
        case .gentleYoga: "https://www.youtube.com/playlist?list=PLKiZXXPoVzxorP43d0OFg04GEEjSe7gBf"
        case .periodYoga: "https://www.youtube.com/watch?v=O-5PXuVlt0Y"
        case .strength: "https://www.youtube.com/watch?v=5D6Uxt82vrg"
        case .intervals: "https://www.youtube.com/watch?v=-iJBEcKIlWs"
        case .bodyweight: "https://www.youtube.com/watch?v=ZTd_Eb2yhiA"
        }
    }
}

/// What the movement tab suggests for today.
public struct MovementSuggestion: Sendable, Hashable {
    /// Why this suggestion; the app words it.
    public enum Focus: Sendable, Hashable, CaseIterable {
        /// Stage 1: showing up matters, not getting tired.
        case habit
        /// Stage 2 on a period day or a day of low energy (1–3).
        case gentle
        /// Stage 2: light training with her own body weight.
        case bodyweight
        /// Stage 3 on a day she marked low energy (1–3): her energy wins over the calendar.
        case lowEnergy
        /// Stage 3 during her period.
        case recovery
        /// Stage 3 in the follicular or ovulatory phase.
        case strength
        /// Stage 3 on a day she marked high energy (8–10).
        case highEnergy
        /// Stage 3 in the luteal phase, or when the phase isn't known.
        case moderate
    }

    public var stage: Int
    public var focus: Focus
    /// What the star logs when she has done it.
    public var kind: WorkoutKind
    public var minutes: ClosedRange<Int>
    public var video: MovementVideo

    public init(stage: Int, focus: Focus, kind: WorkoutKind, minutes: ClosedRange<Int>, video: MovementVideo) {
        self.stage = stage
        self.focus = focus
        self.kind = kind
        self.minutes = minutes
        self.video = video
    }

    /// What the star logs: the shorter end, so kcal are never counted high. She can correct it.
    public var loggedMinutes: Int {
        minutes.lowerBound
    }
}

/// Her movement in one week, Monday to Sunday: a weekly count instead of "days in a row".
public struct MovementWeek: Sendable, Hashable {
    public var monday: LocalDate
    /// The days she moved.
    public var activeDays: Set<LocalDate>
    public var workoutCount: Int
    public var minutes: Int

    public init(monday: LocalDate, activeDays: Set<LocalDate> = [], workoutCount: Int = 0, minutes: Int = 0) {
        self.monday = monday
        self.activeDays = activeDays
        self.workoutCount = workoutCount
        self.minutes = minutes
    }
}

/// The movement plan, a port of the web version's training: today's suggestion, the offer to
/// move up a stage and the week.
public enum WorkoutPlanner {
    /// Today's suggestion by her stage, the phase of the day and the energy she marked today
    /// (1–10: 1–3 is a low day, 8–10 a high one, `SymptomScale`).
    /// - 1 start: 10–15 min of mobility and gentle yoga, the same all cycle long.
    /// - 2 buduj: 15–20 min; training with her own body weight, gentle on period days and on days
    ///   of low energy.
    /// - 3 pełny rytm: 20–30 min matched to the phase, and the energy she marked today always
    ///   wins over the calendar.
    ///
    /// A stage outside 1–3 and an energy outside 1–10 are clamped.
    public static func suggestion(stage: Int, phase: CyclePhase?, energy: Int?) -> MovementSuggestion {
        let stages = TrainingProgress.stages
        let stage = Swift.min(Swift.max(stage, stages.lowerBound), stages.upperBound)
        let level = energy.map(SymptomScale.clamped)
        let isLowEnergy = level.map { SymptomScale.low.contains($0) } ?? false
        let isHighEnergy = level.map { SymptomScale.high.contains($0) } ?? false
        if stage == 1 {
            return MovementSuggestion(stage: 1, focus: .habit, kind: .yoga, minutes: 10...15,
                                      video: phase == .menstrual ? .periodYoga : .gentleYoga)
        }
        if stage == 2 {
            if phase == .menstrual || isLowEnergy {
                return MovementSuggestion(stage: 2, focus: .gentle, kind: .yoga, minutes: 15...15, video: .gentleYoga)
            }
            return MovementSuggestion(stage: 2, focus: .bodyweight, kind: .strength, minutes: 20...20, video: .bodyweight)
        }
        if isLowEnergy {
            return MovementSuggestion(stage: 3, focus: .lowEnergy, kind: .yoga, minutes: 15...15, video: .gentleYoga)
        }
        let isRising = phase == .follicular || phase == .ovulatory
        if isHighEnergy {
            return MovementSuggestion(stage: 3, focus: .highEnergy, kind: isRising ? .intervals : .strength,
                                      minutes: 20...30, video: isRising ? .intervals : .bodyweight)
        }
        if phase == .menstrual {
            return MovementSuggestion(stage: 3, focus: .recovery, kind: .yoga, minutes: 15...20, video: .periodYoga)
        }
        if isRising {
            return MovementSuggestion(stage: 3, focus: .strength, kind: .strength, minutes: 20...30, video: .strength)
        }
        return MovementSuggestion(stage: 3, focus: .moderate, kind: .strength, minutes: 20...20, video: .bodyweight)
    }

    // MARK: - The offer to move up a stage

    /// She is asked about the next stage once she has moved on this many days…
    public static let offerActiveDays = 8
    /// …within the last four weeks, counting only the days after her last answer.
    public static let offerWindowDays = 28
    /// After an answer, or a stage she chose herself, she isn't asked again for at least this long.
    public static let offerPauseDays = 14

    /// The stage to offer her today ("chcesz spróbować etapu 2?"), or nil. Never above stage 3;
    /// the stage is raised only when she says yes.
    public static func stageOffer(for training: TrainingProgress, workouts: [LocalDate: [Workout]],
                                  today: LocalDate) -> Int? {
        guard training.stage < TrainingProgress.stages.upperBound else { return nil }
        var start = today.adding(days: 1 - offerWindowDays)
        if let answeredOn = training.stageOfferAnsweredOn {
            // An answer "in the future" (a changed clock) also waits.
            guard answeredOn.days(to: today) >= offerPauseDays else { return nil }
            start = Swift.max(start, answeredOn.adding(days: 1))
        }
        guard activeDays(in: workouts, from: start, through: today) >= offerActiveDays else { return nil }
        return training.stage + 1
    }

    /// Days with any movement from `start` through `end`; several workouts on one day count once.
    public static func activeDays(in workouts: [LocalDate: [Workout]], from start: LocalDate,
                                  through end: LocalDate) -> Int {
        workouts.reduce(0) { count, entry in
            entry.key >= start && entry.key <= end && !entry.value.isEmpty ? count + 1 : count
        }
    }

    // MARK: - The week

    /// The week `day` falls in, Monday to Sunday.
    public static func week(of day: LocalDate, in workouts: [LocalDate: [Workout]]) -> MovementWeek {
        let monday = day.startOfWeek
        var week = MovementWeek(monday: monday)
        for offset in 0..<7 {
            let date = monday.adding(days: offset)
            let entries = workouts[date] ?? []
            guard !entries.isEmpty else { continue }
            week.activeDays.insert(date)
            week.workoutCount += entries.count
            // Kept within 0–600 a workout, so a damaged file can't overflow the sum.
            week.minutes += entries.reduce(0) { total, workout in
                total + Swift.min(Swift.max(0, workout.minutes), Workout.minuteRange.upperBound)
            }
        }
        return week
    }
}
