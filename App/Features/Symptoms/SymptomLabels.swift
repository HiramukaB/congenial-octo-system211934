import AboutHerCore

// The Polish names of what she can mark about a day, as the web version wrote them.
// `nonisolated`, so every part of the app can use them.

extension EnergyLevel {
    nonisolated var label: String {
        switch self {
        case .low: "niska"
        case .medium: "średnia"
        case .high: "wysoka"
        }
    }
}

extension MoodLevel {
    nonisolated var label: String {
        switch self {
        case .veryGood: "bardzo dobry"
        case .good: "dobry"
        case .neutral: "średni"
        case .low: "obniżony"
        case .veryLow: "niski"
        }
    }
}

extension SleepQuality {
    nonisolated var label: String {
        switch self {
        case .poor: "słaby"
        case .okay: "ok"
        case .good: "dobry"
        }
    }
}

extension AppetiteLevel {
    nonisolated var label: String {
        switch self {
        case .small: "mały"
        case .normal: "normalny"
        case .big: "duży"
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
