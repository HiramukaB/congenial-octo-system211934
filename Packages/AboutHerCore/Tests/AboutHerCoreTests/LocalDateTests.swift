import Foundation
import Testing
@testable import AboutHerCore

@Suite("LocalDate")
struct LocalDateTests {
    @Test func julianDayOfAKnownDate() {
        #expect(LocalDate(year: 2000, month: 1, day: 1).julianDay == 2_451_545)
    }

    @Test func roundTripsThroughJulianDays() {
        var date = LocalDate(year: 1999, month: 12, day: 25)
        for _ in 0..<1_500 {
            #expect(LocalDate(julianDay: date.julianDay) == date)
            #expect(LocalDate(iso: date.iso) == date)
            date = date.adding(days: 1)
        }
    }

    @Test func weekdays() {
        #expect(LocalDate(year: 2000, month: 1, day: 1).isoWeekday == 6)   // sobota
        #expect(LocalDate(year: 2026, month: 11, day: 7).isoWeekday == 6)  // sobota
        #expect(LocalDate(year: 2026, month: 11, day: 9).isoWeekday == 1)  // poniedziałek
        #expect(LocalDate(year: 2026, month: 11, day: 8).isoWeekday == 7)  // niedziela
    }

    @Test func dayDifferencesAcrossFebruary() {
        #expect(LocalDate(year: 2024, month: 2, day: 28).days(to: LocalDate(year: 2024, month: 3, day: 1)) == 2)
        #expect(LocalDate(year: 2026, month: 2, day: 28).days(to: LocalDate(year: 2026, month: 3, day: 1)) == 1)
        #expect(LocalDate(year: 2026, month: 3, day: 1).days(to: LocalDate(year: 2026, month: 2, day: 28)) == -1)
    }

    @Test func outOfRangeValuesRollOver() {
        #expect(LocalDate(year: 2026, month: 13, day: 1) == LocalDate(year: 2027, month: 1, day: 1))
        #expect(LocalDate(year: 2026, month: 0, day: 1) == LocalDate(year: 2025, month: 12, day: 1))
        #expect(LocalDate(year: 2026, month: -11, day: 1) == LocalDate(year: 2025, month: 1, day: 1))
        #expect(LocalDate(year: 2026, month: 6, day: 31) == LocalDate(year: 2026, month: 7, day: 1))
        #expect(LocalDate(year: 2026, month: 3, day: 0) == LocalDate(year: 2026, month: 2, day: 28))
    }

    @Test func monthsAndMonthLengths() {
        #expect(LocalDate(year: 2026, month: 1, day: 31).addingMonths(1) == LocalDate(year: 2026, month: 2, day: 28))
        #expect(LocalDate(year: 2026, month: 12, day: 15).addingMonths(1) == LocalDate(year: 2027, month: 1, day: 15))
        #expect(LocalDate(year: 2026, month: 1, day: 15).addingMonths(-1) == LocalDate(year: 2025, month: 12, day: 15))
        #expect(LocalDate.daysInMonth(year: 2024, month: 2) == 29)
        #expect(LocalDate.daysInMonth(year: 2026, month: 2) == 28)
        #expect(LocalDate.daysInMonth(year: 2026, month: 11) == 30)
    }

    @Test func isoText() {
        #expect(LocalDate(iso: "2026-11-07") == LocalDate(year: 2026, month: 11, day: 7))
        #expect(LocalDate(iso: "2026-11-07T23:30:00.000Z") == LocalDate(year: 2026, month: 11, day: 7))
        #expect(LocalDate(iso: "2026-02-31") == nil)
        #expect(LocalDate(iso: "2026-13-01") == nil)
        #expect(LocalDate(iso: "nonsense") == nil)
        #expect(LocalDate(year: 2026, month: 3, day: 5).iso == "2026-03-05")
    }

    @Test func comparesChronologically() {
        #expect(LocalDate(year: 2025, month: 12, day: 31) < LocalDate(year: 2026, month: 1, day: 1))
        #expect(LocalDate(year: 2026, month: 1, day: 2) > LocalDate(year: 2026, month: 1, day: 1))
    }

    @Test func encodesAsTextAlsoAsADictionaryKey() throws {
        let dictionary: [LocalDate: Int] = [LocalDate(year: 2026, month: 1, day: 2): 3]
        let json = String(decoding: try JSONEncoder().encode(dictionary), as: UTF8.self)
        #expect(json == #"{"2026-01-02":3}"#)
        let decoded = try JSONDecoder().decode([LocalDate: Int].self, from: Data(json.utf8))
        #expect(decoded == dictionary)
    }

    @Test func todayFollowsTheGivenCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Warsaw"))
        // 00:30 on 8 November in Warsaw is still 7 November in UTC – the local day must win.
        let moment = Date(timeIntervalSince1970: 1_794_094_200)
        #expect(LocalDate.today(calendar: calendar, now: moment) == LocalDate(year: 2026, month: 11, day: 8))
    }
}
