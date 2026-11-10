import Foundation

// How she felt on a day. Raw values are stable keys for her data file; the Polish labels live
// in the UI.

/// Her energy on a day.
public enum EnergyLevel: String, Codable, Sendable, CaseIterable {
    case low        // niska
    case medium     // średnia
    case high       // wysoka
}

/// Her mood on a day, from the brightest to the hardest.
public enum MoodLevel: String, Codable, Sendable, CaseIterable {
    case veryGood   // bardzo dobry
    case good       // dobry
    case neutral    // średni
    case low        // obniżony
    case veryLow    // niski
}

/// How she slept.
public enum SleepQuality: String, Codable, Sendable, CaseIterable {
    case poor       // słaby
    case okay       // ok
    case good       // dobry
}

public enum AppetiteLevel: String, Codable, Sendable, CaseIterable {
    case small      // mały
    case normal     // normalny
    case big        // duży
}

/// Symptoms she can mark as present on a day.
public enum SymptomFlag: String, Codable, Sendable, CaseIterable {
    case bloating       // wzdęcia
    case cramps         // skurcze
    case stomachPain    // ból brzucha
    case headache       // ból głowy
    case diarrhea       // biegunka
    case constipation   // zaparcia
    case drowsiness     // senność
}

/// What she marked on one day. Every part is optional: she marks only what she wants to.
public struct SymptomDay: Codable, Sendable, Hashable {
    public var energy: EnergyLevel?
    public var mood: MoodLevel?
    public var sleep: SleepQuality?
    public var appetite: AppetiteLevel?
    public var flags: Set<SymptomFlag>

    public init(energy: EnergyLevel? = nil, mood: MoodLevel? = nil, sleep: SleepQuality? = nil,
                appetite: AppetiteLevel? = nil, flags: Set<SymptomFlag> = []) {
        self.energy = energy
        self.mood = mood
        self.sleep = sleep
        self.appetite = appetite
        self.flags = flags
    }

    /// Nothing marked: such a day isn't stored.
    public var isEmpty: Bool {
        energy == nil && mood == nil && sleep == nil && appetite == nil && flags.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case energy, mood, sleep, appetite, flags
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        energy = try container.decodeIfPresent(EnergyLevel.self, forKey: .energy)
        mood = try container.decodeIfPresent(MoodLevel.self, forKey: .mood)
        sleep = try container.decodeIfPresent(SleepQuality.self, forKey: .sleep)
        appetite = try container.decodeIfPresent(AppetiteLevel.self, forKey: .appetite)
        flags = Set(try container.decodeIfPresent([SymptomFlag].self, forKey: .flags) ?? [])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(energy, forKey: .energy)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(sleep, forKey: .sleep)
        try container.encodeIfPresent(appetite, forKey: .appetite)
        // In a fixed order, so backups compare cleanly.
        try container.encode(SymptomFlag.allCases.filter { flags.contains($0) }, forKey: .flags)
    }
}

extension AppData {
    /// What she marked on `day`; empty when nothing.
    public func symptoms(on day: LocalDate) -> SymptomDay {
        symptoms[day] ?? SymptomDay()
    }

    /// Replaces what she marked on `day`. A day with nothing marked is removed.
    public mutating func setSymptoms(_ symptomDay: SymptomDay, on day: LocalDate) {
        symptoms[day] = symptomDay.isEmpty ? nil : symptomDay
    }
}
