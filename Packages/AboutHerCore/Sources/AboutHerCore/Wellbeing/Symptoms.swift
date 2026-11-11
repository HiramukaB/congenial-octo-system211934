import Foundation

// How she felt on a day: four scales from 1 to 10 (energy, mood, sleep, appetite) and a few
// symptoms. The Polish words for them live in the UI.

/// The four scales of a day – energy, mood, sleep and appetite – each from 1 to 10.
public enum SymptomScale {
    /// Every scale goes from 1 to 10.
    public static let range: ClosedRange<Int> = 1...10
    /// 1–3: a low day on that scale. On a day of low energy the movement plan goes gentle.
    public static let low: ClosedRange<Int> = 1...3
    /// 8–10: a high day on that scale.
    public static let high: ClosedRange<Int> = 8...10

    /// `value` kept within 1–10.
    public static func clamped(_ value: Int) -> Int {
        Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
    }
}

/// Her mood in five bands of the 1–10 scale. "chwila dla siebie" picks its meditation and its
/// intentions per band. The raw values are the words files from before schema 4 stored.
public enum MoodLevel: String, Sendable, CaseIterable {
    case veryGood   // bardzo dobry: 9–10
    case good       // dobry: 7–8
    case neutral    // średni: 5–6
    case low        // obniżony: 3–4
    case veryLow    // niski: 1–2

    /// The band a mood of 1–10 falls in; a value outside 1–10 counts as 1 or 10.
    public init(score: Int) {
        switch SymptomScale.clamped(score) {
        case 9...:
            self = .veryGood
        case 7...8:
            self = .good
        case 5...6:
            self = .neutral
        case 3...4:
            self = .low
        default:
            self = .veryLow
        }
    }

    /// Where a mood marked with this word before schema 4 sits on the 1–10 scale.
    public var score: Int {
        switch self {
        case .veryGood: 9
        case .good: 7
        case .neutral: 5
        case .low: 3
        case .veryLow: 1
        }
    }
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
    /// 1 (low) – 10 (high); nil when not marked.
    public var energy: Int?
    /// 1 (hard) – 10 (very good); nil when not marked.
    public var mood: Int?
    /// 1 (poor) – 10 (good); nil when not marked.
    public var sleep: Int?
    /// 1 (small) – 10 (big); nil when not marked.
    public var appetite: Int?
    public var flags: Set<SymptomFlag>

    /// Values outside 1–10 are clamped.
    public init(energy: Int? = nil, mood: Int? = nil, sleep: Int? = nil,
                appetite: Int? = nil, flags: Set<SymptomFlag> = []) {
        self.energy = energy.map(SymptomScale.clamped)
        self.mood = mood.map(SymptomScale.clamped)
        self.sleep = sleep.map(SymptomScale.clamped)
        self.appetite = appetite.map(SymptomScale.clamped)
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
        energy = try Self.scale(.energy, in: container, words: SymptomLegacyWords.energy)
        mood = try Self.scale(.mood, in: container, words: SymptomLegacyWords.mood)
        sleep = try Self.scale(.sleep, in: container, words: SymptomLegacyWords.sleep)
        appetite = try Self.scale(.appetite, in: container, words: SymptomLegacyWords.appetite)
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

    /// A scale as a number of 1–10 (kept within that range), or – in files from before schema 4 –
    /// as a word, mapped onto the scale. A word this version doesn't know throws: the file then
    /// counts as coming from a newer version and is never saved over.
    private static func scale(_ key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>,
                              words: [String: Int]) throws -> Int? {
        guard container.contains(key), try !container.decodeNil(forKey: key) else { return nil }
        if let number = try? container.decode(Int.self, forKey: key) {
            return SymptomScale.clamped(number)
        }
        let word = try container.decode(String.self, forKey: key)
        guard let value = words[word] else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container,
                                                   debugDescription: "Unknown \(key.stringValue): \(word)")
        }
        return value
    }
}

/// The words files from before schema 4 stored for the scales, and the 1–10 value each stands for.
/// Energy low / medium / high → 2 / 5 / 8. Sleep poor / okay / good → 2 / 5 / 8. Appetite small /
/// normal / big → 2 / 5 / 8. Mood very good / good / neutral / low / very low → 9 / 7 / 5 / 3 / 1
/// (`MoodLevel.score`). So a low-energy day stays low (1–3) for the movement plan, a high one
/// stays high (8–10), and every mood stays in its own band for "chwila dla siebie".
enum SymptomLegacyWords {
    static let energy: [String: Int] = ["low": 2, "medium": 5, "high": 8]
    static let mood: [String: Int] = ["veryGood": 9, "good": 7, "neutral": 5, "low": 3, "veryLow": 1]
    static let sleep: [String: Int] = ["poor": 2, "okay": 5, "good": 8]
    static let appetite: [String: Int] = ["small": 2, "normal": 5, "big": 8]
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
