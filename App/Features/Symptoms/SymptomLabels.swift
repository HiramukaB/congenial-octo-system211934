import AboutHerCore

// The Polish words for what she can mark about a day. The scales are numbers of 1–10; these words
// name their ranges next to the number ("7 · dobry"). `nonisolated`, so every part of the app
// can use them.

/// The words for the ranges of each 1–10 scale, for `DragScale`. Energy, sleep and appetite follow
/// `SymptomScale.low` (1–3) and `.high` (8–10) – on a low-energy day the movement plan goes
/// gentle; mood follows the five bands of `MoodLevel`. Soft, everyday words, nothing clinical.
nonisolated enum SymptomScaleWords {
    static let energy = [ScaleWord(1...3, "niska"), ScaleWord(4...7, "średnia"), ScaleWord(8...10, "wysoka")]
    static let mood = [ScaleWord(1...2, "ciężki"), ScaleWord(3...4, "słabszy"), ScaleWord(5...6, "w porządku"),
                       ScaleWord(7...8, "dobry"), ScaleWord(9...10, "świetny")]
    static let sleep = [ScaleWord(1...3, "słaby"), ScaleWord(4...7, "w porządku"), ScaleWord(8...10, "dobry")]
    static let appetite = [ScaleWord(1...3, "mały"), ScaleWord(4...7, "zwykły"), ScaleWord(8...10, "duży")]
}

/// The four scales of a day, in the order "dziś" and the calendar show them.
nonisolated enum SymptomScaleKind: CaseIterable {
    case energy
    case mood
    case sleep
    case appetite

    var title: String {
        switch self {
        case .energy: "energia"
        case .mood: "nastrój"
        case .sleep: "sen"
        case .appetite: "apetyt"
        }
    }

    /// Where the scale lives in a day's marks – what `AppStore.setSymptomScale` takes.
    var keyPath: WritableKeyPath<SymptomDay, Int?> {
        switch self {
        case .energy: \.energy
        case .mood: \.mood
        case .sleep: \.sleep
        case .appetite: \.appetite
        }
    }

    var words: [ScaleWord] {
        switch self {
        case .energy: SymptomScaleWords.energy
        case .mood: SymptomScaleWords.mood
        case .sleep: SymptomScaleWords.sleep
        case .appetite: SymptomScaleWords.appetite
        }
    }
}

extension MoodLevel {
    /// The name of a band of the mood scale – the same words the mood scale on "dziś" shows.
    nonisolated var label: String {
        switch self {
        case .veryGood: "świetny"
        case .good: "dobry"
        case .neutral: "w porządku"
        case .low: "słabszy"
        case .veryLow: "ciężki"
        }
    }
}

extension SymptomFlag {
    nonisolated var label: String {
        switch self {
        case .bloating: "wzdęcia"
        case .cramps: "skurcze"
        case .stomachPain: "ból brzucha"
        case .headache: "ból głowy"
        case .diarrhea: "biegunka"
        case .constipation: "zaparcia"
        case .drowsiness: "senność"
        }
    }
}
