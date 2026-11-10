import Foundation

// Which of her jokes and quotes to show: one at random for "losuj coś na poprawę humoru", and
// whether "dziś" offers one at all.

extension AppData {
    /// One of her jokes or quotes at random, for "losuj coś na poprawę humoru". Her favourites
    /// come twice as often, and the one shown just before (`previousID`) doesn't come straight
    /// back while there are others. nil while she has none.
    public func randomHumor<Generator: RandomNumberGenerator>(after previousID: UUID? = nil,
                                                              using generator: inout Generator) -> HumorItem? {
        let pool = humor + humor.filter(\.isFavorite)
        let others = pool.filter { $0.id != previousID }
        return (others.isEmpty ? pool : others).randomElement(using: &generator)
    }

    /// `randomHumor(after:using:)` with the system's random numbers.
    public func randomHumor(after previousID: UUID? = nil) -> HumorItem? {
        var generator = SystemRandomNumberGenerator()
        return randomHumor(after: previousID, using: &generator)
    }
}

/// When "dziś" offers her one of her jokes or quotes: only when she has some, and only on a day
/// her mood is low (1–4) – or, while she hasn't marked it, late in the day (the evening of
/// `MeditationTime`: from 18:00 until 4 in the morning). On any other day "dziś" stays as it is.
public enum HumorNudge {
    /// A mood this low ("niski" and "obniżony") brings a smile to "dziś".
    public static let lowMood: ClosedRange<Int> = 1...4

    /// Late enough in the day that a mood not marked yet is reason enough.
    public static func isLate(hour: Int) -> Bool {
        MeditationTime(hour: hour) == .evening
    }

    /// `mood` is today's mood of 1–10 (outside it counts as the nearest end), `hour` the hour on
    /// the clock (0–23).
    public static func offersSmile(mood: Int?, hour: Int, hasHumor: Bool) -> Bool {
        guard hasHumor else { return false }
        guard let mood else { return isLate(hour: hour) }
        return lowMood.contains(SymptomScale.clamped(mood))
    }
}
