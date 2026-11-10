// Marking how she felt: one tap marks a value, a second tap on the same value takes it back.

extension SymptomDay {
    /// Marks `value` on one of the scales (energy, mood, sleep, appetite), or clears that scale
    /// when `value` was already marked, e.g. `toggle(\.mood, .good)`.
    public mutating func toggle<Value: Equatable>(_ scale: WritableKeyPath<SymptomDay, Value?>, _ value: Value) {
        self[keyPath: scale] = self[keyPath: scale] == value ? nil : value
    }

    /// Marks a symptom, or takes it back when it was marked.
    public mutating func toggle(_ flag: SymptomFlag) {
        if flags.contains(flag) {
            flags.remove(flag)
        } else {
            flags.insert(flag)
        }
    }
}
