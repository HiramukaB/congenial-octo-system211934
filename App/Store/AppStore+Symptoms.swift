import Foundation
import AboutHerCore

/// How she felt: energy, mood, sleep, appetite and a few symptoms per day.
extension AppStore {
    /// Replaces what she marked on `day` (today or earlier); a day with nothing marked is removed.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func setSymptoms(_ symptomDay: SymptomDay, on day: LocalDate) -> Bool {
        guard day <= today else { return false }
        return change { $0.setSymptoms(symptomDay, on: day) }
    }

    /// Changes part of what she marked on `day`, e.g. `updateSymptoms(on: day) { $0.mood = .good }`.
    @discardableResult
    func updateSymptoms(on day: LocalDate, _ body: (inout SymptomDay) -> Void) -> Bool {
        guard day <= today else { return false }
        return change { appData in
            var symptomDay = appData.symptoms(on: day)
            body(&symptomDay)
            appData.setSymptoms(symptomDay, on: day)
        }
    }

    /// Marks a symptom on `day`, or takes it away when it was marked.
    @discardableResult
    func toggleSymptom(_ flag: SymptomFlag, on day: LocalDate) -> Bool {
        updateSymptoms(on: day) { $0.toggle(flag) }
    }

    /// Marks a value of one scale on `day`, or clears that scale when the value was marked:
    /// `toggleSymptom(\.mood, .good, on: day)`.
    @discardableResult
    func toggleSymptom<Value: Equatable>(_ scale: WritableKeyPath<SymptomDay, Value?>, _ value: Value,
                                         on day: LocalDate) -> Bool {
        updateSymptoms(on: day) { $0.toggle(scale, value) }
    }
}
