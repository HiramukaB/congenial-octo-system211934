import Foundation
import Testing
@testable import AboutHerCore

@Suite("Humor: drawing one at random, and when \"dziś\" offers a smile")
struct HumorPicksTests {
    /// SplitMix64, so every run draws the same.
    private struct SeededRandom: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }
    }

    /// Made-up entries, oldest first.
    private static func collection(_ count: Int) -> [HumorItem] {
        (0..<count).map { index in
            HumorItem(text: "żart \(index)", kind: .joke,
                      createdAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(index) * 60))
        }
    }

    // Draws are made before `#expect`, so the macros never see an `&` argument.

    @Test func nothingIsDrawnFromAnEmptyCollection() {
        var random = SeededRandom(seed: 1)
        let empty = AppData()
        let drawn = empty.randomHumor(using: &random)
        let drawnAfterOne = empty.randomHumor(after: UUID(), using: &random)
        #expect(drawn == nil)
        #expect(drawnAfterOne == nil)
        #expect(empty.randomHumor() == nil)
    }

    @Test func aSingleOneComesBackEveryTime() {
        var appData = AppData()
        let only = Self.collection(1)[0]
        appData.humor = [only]
        var random = SeededRandom(seed: 2)
        let drawn = appData.randomHumor(using: &random)
        // Also right after itself: it is all she has.
        let drawnAgain = appData.randomHumor(after: only.id, using: &random)
        #expect(drawn == only)
        #expect(drawnAgain == only)
        #expect(appData.randomHumor(after: only.id) == only)
    }

    @Test func noneComesTwiceInARowWhileThereAreOthers() throws {
        var appData = AppData()
        appData.humor = Self.collection(4)
        appData.setHumorFavorite(id: appData.humor[2].id, true)
        var random = SeededRandom(seed: 3)
        var previous: UUID? = nil
        var seen = Set<UUID>()
        for _ in 0..<400 {
            let next = appData.randomHumor(after: previous, using: &random)
            let drawn = try #require(next)
            #expect(drawn.id != previous)
            seen.insert(drawn.id)
            previous = drawn.id
        }
        #expect(seen == Set(appData.humor.map(\.id)))

        // Two, one of them a favourite: they simply take turns.
        appData.humor = Self.collection(2)
        appData.setHumorFavorite(id: appData.humor[0].id, true)
        let firstDraw = appData.randomHumor(using: &random)
        let first = try #require(firstDraw)
        let secondDraw = appData.randomHumor(after: first.id, using: &random)
        let second = try #require(secondDraw)
        let thirdDraw = appData.randomHumor(after: second.id, using: &random)
        let third = try #require(thirdDraw)
        #expect(first.id != second.id)
        #expect(third.id == first.id)
    }

    @Test func favouritesComeTwiceAsOften() {
        var appData = AppData()
        appData.humor = Self.collection(3)
        let favourite = appData.humor[1].id
        appData.setHumorFavorite(id: favourite, true)
        var random = SeededRandom(seed: 4)
        let draws = 4_000
        var counts: [UUID: Int] = [:]
        for _ in 0..<draws {
            if let drawn = appData.randomHumor(using: &random) {
                counts[drawn.id, default: 0] += 1
            }
        }
        #expect(counts.values.reduce(0, +) == draws)
        // Two chances out of four for the favourite, one for each of the other two.
        let favouriteShare = Double(counts[favourite] ?? 0) / Double(draws)
        #expect(favouriteShare > 0.44 && favouriteShare < 0.56)
        for item in appData.humor where item.id != favourite {
            let share = Double(counts[item.id] ?? 0) / Double(draws)
            #expect(share > 0.19 && share < 0.31)
        }
    }

    @Test func todayOffersASmileOnALowMoodOrLateWithoutOne() {
        // A low mood (1–4), at any hour.
        for mood in 1...4 {
            for hour in [0, 7, 12, 17, 20] {
                #expect(HumorNudge.offersSmile(mood: mood, hour: hour, hasHumor: true))
            }
        }
        // A mood of 5 or more: never, also late.
        for mood in 5...10 {
            for hour in [0, 7, 12, 17, 20, 23] {
                #expect(!HumorNudge.offersSmile(mood: mood, hour: hour, hasHumor: true))
            }
        }
        // No mood marked yet: only late in the day – from 18:00 and in the small hours.
        for hour in [18, 21, 23, 0, 3] {
            #expect(HumorNudge.isLate(hour: hour))
            #expect(HumorNudge.offersSmile(mood: nil, hour: hour, hasHumor: true))
        }
        for hour in [4, 9, 12, 17] {
            #expect(!HumorNudge.isLate(hour: hour))
            #expect(!HumorNudge.offersSmile(mood: nil, hour: hour, hasHumor: true))
        }
        // With nothing in her collection, nothing to offer.
        #expect(!HumorNudge.offersSmile(mood: 2, hour: 12, hasHumor: false))
        #expect(!HumorNudge.offersSmile(mood: nil, hour: 22, hasHumor: false))
        // A mood outside the scale counts as its nearest end.
        #expect(HumorNudge.offersSmile(mood: 0, hour: 12, hasHumor: true))
        #expect(HumorNudge.offersSmile(mood: -3, hour: 12, hasHumor: true))
        #expect(!HumorNudge.offersSmile(mood: 14, hour: 22, hasHumor: true))
        #expect(HumorNudge.lowMood == 1...4)
    }
}
