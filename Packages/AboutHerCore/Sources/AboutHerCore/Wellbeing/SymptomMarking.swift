// Marking how she felt: a scale is set by dragging along it (1–10), a symptom is marked with one
// tap and taken back with a second one.

extension SymptomDay {
    /// Sets one of the scales (energy, mood, sleep, appetite) to `value`, kept within 1–10, or
    /// clears it with nil: `set(\.energy, to: 7)`.
    public mutating func set(_ scale: WritableKeyPath<SymptomDay, Int?>, to value: Int?) {
        self[keyPath: scale] = value.map(SymptomScale.clamped)
    }

    /// Marks `value` on one of the scales, or clears that scale when `value` was already marked,
    /// e.g. `toggle(\.mood, 7)`.
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
