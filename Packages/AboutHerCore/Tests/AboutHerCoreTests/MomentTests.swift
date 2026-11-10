import Foundation
import Testing
@testable import AboutHerCore

@Suite("Chwila dla siebie: meditations, intentions and the question deck")
struct MomentTests {
    /// Every mood, and no mood at all.
    private static let moods: [MoodLevel?] = [nil] + MoodLevel.allCases.map { Optional($0) }

    /// Pronouns that address her are always capitalised in the app's texts.
    private static let lowercaseAddress: Set<String> = [
        "ty", "ci", "cię", "ciebie", "tobie", "tobą", "twój", "twoja", "twoje", "twoich", "twoim",
        "twoją", "twojej", "twoimi", "twojego", "twojemu",
    ]

    private static func addressesHerInLowercase(_ text: String) -> Bool {
        text.split { !$0.isLetter }.contains { lowercaseAddress.contains(String($0)) }
    }

    @Test func partsOfTheDayFollowTheClock() {
        #expect(MeditationTime(hour: 4) == .morning)
        #expect(MeditationTime(hour: 10) == .morning)
        #expect(MeditationTime(hour: 11) == .day)
        #expect(MeditationTime(hour: 17) == .day)
        #expect(MeditationTime(hour: 18) == .evening)
        #expect(MeditationTime(hour: 23) == .evening)
        // In the small hours what helps is falling asleep again.
        #expect(MeditationTime(hour: 0) == .evening)
        #expect(MeditationTime(hour: 3) == .evening)
    }

    @Test func everyPartOfTheDayAndMoodHasAMeditationToOpen() throws {
        for time in MeditationTime.allCases {
            for mood in Self.moods {
                let meditation = MeditationGuide.meditation(for: time, mood: mood)
                #expect(meditation.title.first?.isLowercase == true)
                let url = try #require(meditation.url)
                #expect(url.scheme == "https")
                #expect(url.host == "www.youtube.com")
            }
        }
        // Without a mood, the meditation for a "średni" day.
        for time in MeditationTime.allCases {
            #expect(MeditationGuide.meditation(for: time, mood: nil) == MeditationGuide.meditation(for: time, mood: .neutral))
        }
        // A hard evening gets something else than a bright one.
        #expect(MeditationGuide.meditation(for: .evening, mood: .veryLow)
                != MeditationGuide.meditation(for: .evening, mood: .veryGood))
    }

    @Test func intentionsSuitHerMoodAndTakeTurns() {
        let all = MeditationGuide.intentions(for: nil)
        #expect(all.count >= 20)
        #expect(Set(all).count == all.count)
        for intention in all {
            #expect(intention.first?.isLowercase == true)
            #expect(!Self.addressesHerInLowercase(intention), "\(intention)")
        }
        let day = LocalDate(year: 2026, month: 11, day: 10)
        for mood in Self.moods {
            let choices = MeditationGuide.intentions(for: mood)
            #expect(choices.count >= 7)
            #expect(Set(choices).count == choices.count)
            #expect(Set(choices).isSubset(of: Set(all)))
            // Asked for another again and again, she sees every one once before any comes back.
            let offered = (0..<choices.count).map { MeditationGuide.intention(for: mood, on: day, offset: $0) }
            #expect(Set(offered) == Set(choices))
            #expect(MeditationGuide.intention(for: mood, on: day, offset: choices.count) == offered[0])
            // The next day starts with another one.
            #expect(MeditationGuide.intention(for: mood, on: day.adding(days: 1)) == offered[1])
        }
        // The hardest days are offered only the gentlest ones, the brightest days none of those.
        #expect(MeditationGuide.intentions(for: .veryLow) == MeditationGuide.gentleIntentions)
        #expect(Set(MeditationGuide.intentions(for: .veryGood)).isDisjoint(with: MeditationGuide.gentleIntentions))
        // Any offset is safe.
        #expect(all.contains(MeditationGuide.intention(for: nil, on: day, offset: -7)))
        #expect(all.contains(MeditationGuide.intention(for: nil, on: day, offset: Int.max)))
    }

    @Test func theDeckHoldsSixtyShortOpenQuestions() {
        let questions = QuestionDeck.questions
        #expect(questions.count == 60)
        #expect(Set(questions).count == questions.count)
        for question in questions {
            #expect(question.hasSuffix("?"), "\(question)")
            #expect(question.first?.isLowercase == true, "\(question)")
            #expect(question.count <= 80, "\(question)")
            #expect(!Self.addressesHerInLowercase(question), "\(question)")
        }
    }

    @Test func everyRoundShowsEachCardOnceInItsOwnOrder() {
        let questions = QuestionDeck.questions
        let count = questions.count
        var rounds: [[String]] = []
        for round in 0..<6 {
            let cards = (0..<count).map { QuestionDeck.question(at: round * count + $0) }
            #expect(cards.count == count)
            #expect(Set(cards) == Set(questions))
            rounds.append(cards)
        }
        #expect(rounds[0] != questions)
        #expect(Set(rounds).count == rounds.count)
        // No card twice in a row, also where one round ends and the next begins. (Without the swap,
        // rounds 9, 85, 90 and 139 would start with the card the round before them ended on.)
        for round in 1..<200 {
            #expect(QuestionDeck.question(at: round * count - 1) != QuestionDeck.question(at: round * count))
            #expect(Set(QuestionDeck.order(ofRound: round)) == Set(0..<count))
        }
        #expect(QuestionDeck.question(at: -3) == QuestionDeck.question(at: 0))
        #expect(questions.contains(QuestionDeck.question(at: Int.max)))
    }

    @Test func cardsAreNumberedWithinTheirRound() {
        let count = QuestionDeck.questions.count
        #expect(QuestionDeck.cardNumber(at: 0) == 1)
        #expect(QuestionDeck.cardNumber(at: count - 1) == count)
        #expect(QuestionDeck.cardNumber(at: count) == 1)
        #expect(QuestionDeck.cardNumber(at: -5) == 1)
        #expect(QuestionDeck.cardNumber(at: Int.max) >= 1)
    }

    @Test func notesAreStoredWithStableKeys() throws {
        let raw = Data(#"""
        {"day":"2026-11-08","id":"6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C","kind":"answer","prompt":"co chroni Twój spokój?","text":"spacer bez telefonu"}
        """#.utf8)
        let note = try JSONDecoder().decode(MomentNote.self, from: raw)
        #expect(note.kind == .answer)
        #expect(note.day == LocalDate(year: 2026, month: 11, day: 8))
        #expect(note.prompt == "co chroni Twój spokój?")
        #expect(MomentNote.Kind.allCases.map(\.rawValue) == ["answer", "intention"])
        let encoded = try JSONEncoder().encode(note)
        #expect(try JSONDecoder().decode(MomentNote.self, from: encoded) == note)
    }
}
