import Foundation

/// Something she wrote in "chwila dla siebie": her answer to a question card, or her intention
/// for a meditation.
public struct MomentNote: Codable, Sendable, Hashable, Identifiable {
    /// Raw values are stable keys for her data file.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// Her answer to a question card.
        case answer
        /// Her intention for a meditation.
        case intention
    }

    public var id: UUID
    public var day: LocalDate
    public var kind: Kind
    /// The question on the card, or the intention she was offered, as she saw it; empty when the
    /// words are all hers.
    public var prompt: String
    /// What she wrote.
    public var text: String

    public init(id: UUID = UUID(), day: LocalDate, kind: Kind, prompt: String, text: String) {
        self.id = id
        self.day = day
        self.kind = kind
        self.prompt = prompt
        self.text = text
    }
}

// MARK: - Meditation

/// The part of the day a meditation is picked for: "rano" from 4 to 11, "dzień" until 18, then
/// "wieczór" – also in the small hours, when what helps most is falling asleep again.
public enum MeditationTime: Sendable, CaseIterable {
    case morning
    case day
    case evening

    /// The part of the day at `hour` on the clock (0–23).
    public init(hour: Int) {
        switch hour {
        case 4..<11:
            self = .morning
        case 11..<18:
            self = .day
        default:
            self = .evening
        }
    }
}

/// A guided meditation she can open on YouTube.
public struct Meditation: Sendable, Hashable {
    /// Lowercase, as shown in the app.
    public let title: String
    public let link: String

    public init(title: String, link: String) {
        self.title = title
        self.link = link
    }

    /// `nil` only for a malformed link; the app then offers nothing to open.
    public var url: URL? {
        URL(string: link)
    }
}

/// What "chwila dla siebie" offers: a meditation for the part of the day and her mood, and a short
/// intention to take into it. Suggestions only – she can always pick another.
public enum MeditationGuide {
    /// The meditation for this part of the day and mood; without a mood, the one for a "średni" day.
    /// The same meditations as in the web version.
    public static func meditation(for time: MeditationTime, mood: MoodLevel?) -> Meditation {
        let level: MoodLevel = mood ?? .neutral
        switch (time, level) {
        case (.morning, .veryGood):
            return Meditation(title: "poranna medytacja na dobry dzień",
                              link: "https://www.youtube.com/playlist?list=PLAU4WUkbbzhp54tKPDtWHtx5QhxP_p0nP")
        case (.morning, .good):
            return Meditation(title: "poranna medytacja na dobry dzień",
                              link: "https://www.youtube.com/watch?v=TFtylB60zSo")
        case (.morning, .neutral):
            return Meditation(title: "poranne wyciszenie – oddech i uważność",
                              link: "https://www.youtube.com/watch?v=rbnnXb_Frrc")
        case (.morning, .low):
            return Meditation(title: "łagodny początek dnia",
                              link: "https://www.youtube.com/watch?v=PSTTeT0-Zio")
        case (.day, .veryGood), (.day, .good):
            return Meditation(title: "krótka medytacja uważności",
                              link: "https://www.youtube.com/watch?v=rbnnXb_Frrc")
        case (.day, .neutral):
            return Meditation(title: "oddech i uważność w środku dnia",
                              link: "https://www.youtube.com/watch?v=rbnnXb_Frrc")
        case (.day, .low):
            return Meditation(title: "medytacja na stres",
                              link: "https://www.youtube.com/watch?v=PSTTeT0-Zio")
        case (.morning, .veryLow), (.day, .veryLow):
            return Meditation(title: "medytacja uzdrawiająca – łagodne wsparcie",
                              link: "https://www.youtube.com/watch?v=Y9q5QBrBBRU")
        case (.evening, .veryGood), (.evening, .good):
            return Meditation(title: "medytacja wdzięczności na sen",
                              link: "https://www.youtube.com/watch?v=XFVGnwc5_zE")
        case (.evening, .neutral):
            return Meditation(title: "wieczorne wyciszenie – 15 minut",
                              link: "https://www.youtube.com/watch?v=WxqardbiQ3Q")
        case (.evening, .low):
            return Meditation(title: "relaksacja przed snem na wyciszenie",
                              link: "https://www.youtube.com/watch?v=FA6bKRv_eYI")
        case (.evening, .veryLow):
            return Meditation(title: "medytacja na sen z afirmacjami",
                              link: "https://www.youtube.com/watch?v=J_YCQnXP1pc")
        }
    }

    /// The intentions that suit her mood: brighter ones on good days, the gentlest on hard days.
    /// Without a mood, all of them.
    public static func intentions(for mood: MoodLevel?) -> [String] {
        switch mood {
        case .veryGood?, .good?:
            return brightIntentions + steadyIntentions
        case .neutral?:
            return steadyIntentions + gentleIntentions
        case .low?:
            return gentleIntentions + steadyIntentions
        case .veryLow?:
            return gentleIntentions
        case nil:
            return steadyIntentions + gentleIntentions + brightIntentions
        }
    }

    /// The intention to offer on `day`: another one each day, and the next one each time she asks
    /// for another (`offset`), so every one that suits her mood comes once before any comes back.
    public static func intention(for mood: MoodLevel?, on day: LocalDate, offset: Int = 0) -> String {
        let choices = intentions(for: mood)
        guard !choices.isEmpty else { return "" }
        let index = (day.julianDay &+ offset) % choices.count
        return choices[index < 0 ? index + choices.count : index]
    }

    static let brightIntentions = [
        "wdzięczność za mały krok",
        "radość z tego, co jest",
        "ciekawość tego dnia",
        "lekkość w ciele i w myślach",
        "dzielę się dobrem, które mam",
        "otwieram się na nowe",
        "świętuję to, co mi się udaje",
    ]

    static let steadyIntentions = [
        "zaufanie do ciała",
        "jestem tu i teraz",
        "jeden oddech naraz",
        "słucham siebie uważnie",
        "spokój, który noszę w sobie",
        "równowaga między działaniem a odpoczynkiem",
        "uważność na drobiazgi",
    ]

    static let gentleIntentions = [
        "łagodność wobec siebie",
        "odpuszczam to, co nie moje",
        "wystarczy, że jestem",
        "pozwalam sobie odpocząć",
        "mogę czuć to, co czuję",
        "przyjmuję ten dzień takim, jaki jest",
        "jestem dla siebie czuła",
    ]
}
