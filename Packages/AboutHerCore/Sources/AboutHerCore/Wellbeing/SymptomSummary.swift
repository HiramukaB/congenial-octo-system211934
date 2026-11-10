// What she marked on a day, at a glance: how many of the scales, and her symptoms in the order
// the app lists them.

extension SymptomDay {
    /// How many of the four scales – energy, mood, sleep, appetite – she marked (0–4).
    public var markedScaleCount: Int {
        [energy, mood, sleep, appetite].filter { $0 != nil }.count
    }

    /// She marked all four scales.
    public var hasEveryScale: Bool {
        markedScaleCount == 4
    }

    /// Her symptoms in the order the app lists them (`SymptomFlag.allCases`).
    public var orderedFlags: [SymptomFlag] {
        SymptomFlag.allCases.filter { flags.contains($0) }
    }
}
