import Foundation
import Testing
@testable import AboutHerCore

@Suite("Schema 4: symptom scales of 1–10, her name and the welcome, humor")
struct SchemaFourTests {
    /// The shape 0.1.19 writes (schema 3), every scale with each of its words. Made-up values.
    private static let schema3File = Data(#"""
    {
      "intentions" : { "2026-03-02" : "spokojnie" },
      "periodDays" : [ "2026-02-20", "2026-02-21" ],
      "schemaVersion" : 3,
      "settings" : {
        "isLockEnabled" : false,
        "reminders" : { "water" : { "isOn" : true, "time" : { "hour" : 11, "minute" : 0 } } }
      },
      "symptoms" : {
        "2026-03-02" : { "appetite" : "small", "energy" : "low", "flags" : [ "bloating" ], "mood" : "veryGood", "sleep" : "poor" },
        "2026-03-03" : { "appetite" : "normal", "energy" : "medium", "flags" : [ ], "mood" : "good", "sleep" : "okay" },
        "2026-03-04" : { "appetite" : "big", "energy" : "high", "flags" : [ ], "mood" : "neutral", "sleep" : "good" },
        "2026-03-05" : { "flags" : [ "cramps", "headache" ], "mood" : "low" },
        "2026-03-06" : { "flags" : [ ], "mood" : "veryLow" }
      },
      "training" : { "stage" : 2 },
      "workouts" : { }
    }
    """#.utf8)

    private static let march2 = LocalDate(year: 2026, month: 3, day: 2)

    /// Reads only the scales of a written file, as numbers: a word there would fail to decode.
    private struct WrittenScales: Decodable {
        struct Day: Decodable {
            let energy: Int?
            let mood: Int?
            let sleep: Int?
            let appetite: Int?
        }

        let schemaVersion: Int
        let symptoms: [String: Day]
    }

    @Test func aSchema3FileReadsItsWordsAsValuesOfOneToTen() throws {
        #expect(!AppDataCoding.isFromNewerVersion(Self.schema3File))
        let appData = try AppDataCoding.decode(Self.schema3File)
        let day = Self.march2
        #expect(appData.symptoms(on: day) == SymptomDay(energy: 2, mood: 9, sleep: 2, appetite: 2, flags: [.bloating]))
        #expect(appData.symptoms(on: day.adding(days: 1)) == SymptomDay(energy: 5, mood: 7, sleep: 5, appetite: 5))
        #expect(appData.symptoms(on: day.adding(days: 2)) == SymptomDay(energy: 8, mood: 5, sleep: 8, appetite: 8))
        #expect(appData.symptoms(on: day.adding(days: 3)) == SymptomDay(mood: 3, flags: [.cramps, .headache]))
        #expect(appData.symptoms(on: day.adding(days: 4)) == SymptomDay(mood: 1))
        // Everything else keeps its meaning.
        #expect(appData.periodDays.count == 2)
        #expect(appData.intention(on: day) == "spokojnie")
        #expect(appData.training.stage == 2)
        #expect(appData.settings.reminders.water.isOn)
        // Nothing of schema 4 yet: the welcome shows once, with her data already there.
        #expect(appData.settings.onboarding == OnboardingState())
        #expect(appData.humor.isEmpty)
    }

    @Test func aSchema3FileIsWrittenBackWithNumbersAndReadsTheSame() throws {
        let appData = try AppDataCoding.decode(Self.schema3File)
        let written = try AppDataCoding.encode(appData)
        #expect(!AppDataCoding.isFromNewerVersion(written))
        var current = appData
        current.schemaVersion = AppData.currentSchemaVersion
        #expect(try AppDataCoding.decode(written) == current)

        let scales = try JSONDecoder().decode(WrittenScales.self, from: written)
        #expect(scales.schemaVersion == 4)
        #expect(AppData.currentSchemaVersion == 4)
        let first = try #require(scales.symptoms["2026-03-02"])
        #expect(first.energy == 2 && first.mood == 9 && first.sleep == 2 && first.appetite == 2)
        let last = try #require(scales.symptoms["2026-03-06"])
        #expect(last.mood == 1 && last.energy == nil && last.sleep == nil && last.appetite == nil)
    }

    @Test func numbersOutsideTheScaleAreKeptWithinIt() throws {
        let raw = Data(#"{"schemaVersion":4,"symptoms":{"2026-03-02":{"energy":0,"mood":14,"sleep":-2,"appetite":10,"flags":[]}}}"#.utf8)
        #expect(!AppDataCoding.isFromNewerVersion(raw))
        let appData = try AppDataCoding.decode(raw)
        #expect(appData.symptoms(on: Self.march2) == SymptomDay(energy: 1, mood: 10, sleep: 1, appetite: 10))
        // A missing or null scale is simply not marked.
        let partial = Data(#"{"symptoms":{"2026-03-02":{"energy":null,"mood":6}}}"#.utf8)
        #expect(try AppDataCoding.decode(partial).symptoms(on: Self.march2) == SymptomDay(mood: 6))
    }

    @Test func everySchema4FieldRoundTrips() throws {
        var appData = AppData()
        appData.setSymptoms(SymptomDay(energy: 4, mood: 6, sleep: 7, appetite: 3, flags: [.drowsiness]), on: Self.march2)
        appData.settings.onboarding = OnboardingState(name: "  Ola ",
                                                      completedAt: Date(timeIntervalSince1970: 1_800_000_000),
                                                      hasSeenTutorial: true)
        let added = Date(timeIntervalSince1970: 1_800_003_600)
        appData.humor = [
            HumorItem(text: "kawa najpierw, potem cała reszta", kind: .joke, createdAt: added),
            HumorItem(text: "spokojnie, to tylko poniedziałek", kind: .quote, source: " Ola ",
                      createdAt: added.addingTimeInterval(60), isFavorite: true),
            HumorItem(text: "uśmiech z wczorajszego spaceru", kind: .other, source: "   ",
                      createdAt: added.addingTimeInterval(120)),
        ]
        // Names and sources are kept without the spaces around them; a blank one is no source.
        #expect(appData.settings.onboarding.name == "Ola")
        #expect(appData.humor[1].source == "Ola")
        #expect(appData.humor[2].source == nil)

        let encoded = try AppDataCoding.encode(appData)
        #expect(!AppDataCoding.isFromNewerVersion(encoded))
        let decoded = try AppDataCoding.decode(encoded)
        #expect(decoded == appData)
        #expect(decoded.settings.onboarding.isCompleted)
        #expect(decoded.settings.onboarding.hasSeenTutorial)
        #expect(decoded.humor.map(\.kind) == [.joke, .quote, .other])
        #expect(decoded.humor.filter(\.isFavorite).count == 1)
        #expect(HumorItem.Kind.allCases.map(\.rawValue) == ["joke", "quote", "other"])
    }

    @Test func filesFromANewerVersionStayReadOnlyInSchema4() {
        let newer = AppData.currentSchemaVersion + 1
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":\#(newer),"humor":[]}"#.utf8)))
        // A top-level key this version doesn't know.
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":4,"humor":[],"stickers":[]}"#.utf8)))
        // A kind of humor only a newer version knows, deep inside.
        #expect(AppDataCoding.isFromNewerVersion(Data(#"""
        {"schemaVersion":4,"humor":[{"createdAt":"2026-03-02T08:00:00Z","id":"6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C","kind":"meme","text":"x"}]}
        """#.utf8)))
        // A word for a scale no version of this app ever wrote.
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":3,"symptoms":{"2026-03-02":{"energy":"ogromna"}}}"#.utf8)))
        // This version's own fields are known.
        #expect(!AppDataCoding.isFromNewerVersion(Data(#"""
        {"schemaVersion":4,"humor":[{"createdAt":"2026-03-02T08:00:00Z","id":"6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C","kind":"quote","text":"x"}],"settings":{"onboarding":{"name":"Ola","hasSeenTutorial":false}}}
        """#.utf8)))
    }

    @Test func humorIsSavedCorrectedMarkedAndRemoved() throws {
        var appData = AppData()
        let first = HumorItem(text: "pierwszy", kind: .joke, createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        let second = HumorItem(text: "drugi", kind: .quote, createdAt: Date(timeIntervalSince1970: 1_800_000_600))
        appData.saveHumor(first)
        appData.saveHumor(second)
        #expect(appData.humorNewestFirst.map(\.id) == [second.id, first.id])

        // Saved again under its id, it is corrected in its place and keeps the time it was added.
        var corrected = first
        corrected.text = "pierwszy, poprawiony"
        corrected.kind = .other
        corrected.createdAt = Date(timeIntervalSince1970: 1_900_000_000)
        appData.saveHumor(corrected)
        #expect(appData.humor.map(\.id) == [first.id, second.id])
        #expect(appData.humor[0].text == "pierwszy, poprawiony")
        #expect(appData.humor[0].kind == .other)
        #expect(appData.humor[0].createdAt == first.createdAt)

        appData.setHumorFavorite(id: second.id, true)
        #expect(appData.humor[1].isFavorite)
        appData.setHumorFavorite(id: UUID(), true)
        #expect(appData.humor.filter(\.isFavorite).count == 1)

        appData.removeHumor(id: first.id)
        #expect(appData.humor.map(\.id) == [second.id])
        appData.removeHumor(id: second.id)
        #expect(appData.humor.isEmpty)
    }

    @Test func eachDayBringsAnotherJokeAndFavouritesComeMoreOften() throws {
        var appData = AppData()
        #expect(appData.humorItem(for: Self.march2) == nil)
        let items = (0..<3).map { index in
            HumorItem(text: "żart \(index)", kind: .joke, createdAt: Date(timeIntervalSince1970: 1_800_000_000 + Double(index)))
        }
        appData.humor = items
        // Three days in a row show all three, then it starts again.
        let shown = (0..<3).compactMap { appData.humorItem(for: Self.march2.adding(days: $0))?.id }
        #expect(Set(shown) == Set(items.map(\.id)))
        #expect(appData.humorItem(for: Self.march2.adding(days: 3)) == appData.humorItem(for: Self.march2))

        // A favourite shows on two days out of four.
        appData.setHumorFavorite(id: items[1].id, true)
        let fourDays = (0..<4).compactMap { appData.humorItem(for: Self.march2.adding(days: $0))?.id }
        #expect(fourDays.count == 4)
        #expect(fourDays.filter { $0 == items[1].id }.count == 2)
        // Any day is safe, also long before the calendar starts.
        #expect(appData.humorItem(for: LocalDate(julianDay: -12345)) != nil)
    }

    @Test func aBlankNameIsNoName() {
        #expect(OnboardingState(name: "   ").name == nil)
        #expect(OnboardingState(name: "\n").name == nil)
        #expect(OnboardingState(name: " Ola\n").name == "Ola")
        #expect(OnboardingState.cleanName(nil) == nil)
        #expect(!OnboardingState().isCompleted)
        #expect(OnboardingState(completedAt: Date(timeIntervalSince1970: 0)).isCompleted)
    }
}
