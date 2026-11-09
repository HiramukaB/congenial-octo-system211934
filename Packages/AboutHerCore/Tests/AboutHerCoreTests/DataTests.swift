import Foundation
import Testing
@testable import AboutHerCore

@Suite("Data and wording")
struct DataTests {
    @Test func appDataRoundTripsWithSortedDays() throws {
        var appData = AppData()
        appData.togglePeriodDay(LocalDate(year: 2025, month: 3, day: 2))
        appData.togglePeriodDay(LocalDate(year: 2025, month: 3, day: 1))

        let encoded = try AppDataCoding.encode(appData)
        let json = String(decoding: encoded, as: UTF8.self)
        let earlier = try #require(json.range(of: "2025-03-01"))
        let later = try #require(json.range(of: "2025-03-02"))
        #expect(earlier.lowerBound < later.lowerBound)
        #expect(try AppDataCoding.decode(encoded) == appData)
    }

    @Test func missingFieldsFallBackToDefaults() throws {
        let appData = try AppDataCoding.decode(Data("{}".utf8))
        #expect(appData.periodDays.isEmpty)
        #expect(appData.schemaVersion == AppData.currentSchemaVersion)
    }

    @Test func recognisesFilesWrittenByANewerVersion() throws {
        #expect(!AppDataCoding.isFromNewerVersion(try AppDataCoding.encode(AppData())))
        #expect(!AppDataCoding.isFromNewerVersion(Data("{}".utf8)))
        #expect(!AppDataCoding.isFromNewerVersion(Data("not json".utf8)))
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":2,"periodDays":[]}"#.utf8)))
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":1,"periodDays":[],"meals":[]}"#.utf8)))
    }

    @Test func togglingTwiceRemovesTheDay() {
        var appData = AppData()
        let day = LocalDate(year: 2025, month: 5, day: 5)
        appData.togglePeriodDay(day)
        appData.togglePeriodDay(day)
        #expect(appData.periodDays.isEmpty)
    }

    @Test func polishWording() {
        let saturday = LocalDate(year: 2026, month: 11, day: 7)
        #expect(PolishDate.short(LocalDate(year: 2026, month: 9, day: 5)) == "5 wrz")
        #expect(PolishDate.dayMonth(saturday) == "7 listopada")
        #expect(PolishDate.long(saturday) == "sobota, 7 listopada")
        #expect(PolishDate.monthYear(saturday) == "listopad 2026")
        #expect(PolishDate.range(LocalDate(year: 2026, month: 8, day: 31), LocalDate(year: 2026, month: 9, day: 15)) == "31 sie – 15 wrz")
        #expect(PolishDate.range(LocalDate(year: 2026, month: 10, day: 24), LocalDate(year: 2026, month: 10, day: 28)) == "24–28 paź")
        #expect(PolishDate.range(saturday, saturday) == "7 lis")
        #expect(PolishPlural.days(1) == "1 dzień")
        #expect(PolishPlural.days(2) == "2 dni")
        #expect(PolishPlural.days(12) == "12 dni")
    }
}
