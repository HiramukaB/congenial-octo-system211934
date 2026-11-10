import Foundation
import Testing
@testable import AboutHerCore

@Suite("Reminders for the coming week")
struct RemindersTests {
    /// Tuesday, 10 November 2026.
    private static let tuesday = LocalDate(year: 2026, month: 11, day: 10)

    private static func warsaw() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Warsaw"))
        return calendar
    }

    private static func moment(_ day: LocalDate, _ hour: Int, _ minute: Int = 0, in calendar: Calendar) throws -> Date {
        let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
        return try #require(calendar.date(from: components))
    }

    /// Empty data with these reminders turned on.
    private static func appData(turningOn kinds: [ReminderKind]) -> AppData {
        var data = AppData()
        for kind in kinds {
            data.settings.reminders[kind].isOn = true
        }
        return data
    }

    @Test func nothingIsPlannedUntilSheTurnsSomethingOn() throws {
        let calendar = try Self.warsaw()
        var data = AppData()
        data.letters = [Letter(writtenOn: Self.tuesday.adding(days: -90), opensOn: Self.tuesday, text: "cześć")]
        let now = try Self.moment(Self.tuesday, 7, in: calendar)
        #expect(!data.settings.reminders.isAnyOn)
        #expect(ReminderPlan.reminders(for: data, now: now, calendar: calendar).isEmpty)
    }

    @Test func defaultsAreOnlySuggestions() {
        let reminders = ReminderSettings()
        #expect(!reminders.isAnyOn)
        #expect(reminders.water.time == ReminderTime(hour: 11))
        #expect(reminders.weighIn.time == ReminderTime(hour: 8))
        #expect(reminders.weighInWeekday == 1)
        #expect(reminders.periodSoon.time == ReminderTime(hour: 9))
        #expect(reminders.dinner.time == ReminderTime(hour: 20))
        #expect(reminders.letter.time == ReminderTime(hour: 9))

        var settings = ReminderSettings()
        for kind in ReminderKind.allCases {
            settings[kind].isOn = true
        }
        #expect([settings.water, settings.weighIn, settings.periodSoon, settings.dinner, settings.letter]
                    .allSatisfy { $0.isOn })
        settings[.dinner].time = ReminderTime(hour: 19, minute: 30)
        #expect(settings.dinner.time == ReminderTime(hour: 19, minute: 30))
        #expect(ReminderTime(hour: 8).text == "8:00")
        #expect(ReminderTime(hour: 19, minute: 5).text == "19:05")
    }

    @Test func waterComesThreeTimesADayUntilSheDrankHerGlasses() throws {
        let calendar = try Self.warsaw()
        var data = Self.appData(turningOn: [.water])
        let morning = try Self.moment(Self.tuesday, 10, in: calendar)

        let week = ReminderPlan.reminders(for: data, now: morning, calendar: calendar)
        #expect(week.count == 21)
        #expect(week.allSatisfy { $0.kind == .water && $0.title == "woda" })
        #expect(week.prefix(3).map(\.time) == [ReminderTime(hour: 11), ReminderTime(hour: 15), ReminderTime(hour: 19)])
        #expect(week.prefix(3).allSatisfy { $0.day == Self.tuesday })
        #expect(week.last?.day == Self.tuesday.adding(days: 6))
        #expect(week.first?.identifier == "abouther.water.2026-11-10.1100")
        // 11:00 in Warsaw is 10:00 UTC in November.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let tenUTC = try Self.moment(Self.tuesday, 10, in: utc)
        #expect(week.first?.date == tenUTC)

        // Past 16:00 only the evening one is left today.
        let afternoon = try Self.moment(Self.tuesday, 16, in: calendar)
        #expect(ReminderPlan.reminders(for: data, now: afternoon, calendar: calendar).count == 19)

        // Once she drank her glasses the rest of today is skipped; the next days stay.
        data.addWater(WaterDay.goalGlasses, to: .morning, on: Self.tuesday)
        let afterGoal = ReminderPlan.reminders(for: data, now: morning, calendar: calendar)
        #expect(afterGoal.count == 18)
        #expect(afterGoal.allSatisfy { $0.day > Self.tuesday })
    }

    @Test func laterWaterRemindersFollowHerFirstTimeButNotLateIntoTheEvening() {
        var reminders = ReminderSettings()
        #expect(reminders.waterTimes == [ReminderTime(hour: 11), ReminderTime(hour: 15), ReminderTime(hour: 19)])
        reminders.water.time = ReminderTime(hour: 8, minute: 30)
        #expect(reminders.waterTimes == [ReminderTime(hour: 8, minute: 30), ReminderTime(hour: 12, minute: 30),
                                         ReminderTime(hour: 16, minute: 30)])
        reminders.water.time = ReminderTime(hour: 13)
        #expect(reminders.waterTimes == [ReminderTime(hour: 13), ReminderTime(hour: 17)])
        // Her own first time always stays, even late.
        reminders.water.time = ReminderTime(hour: 21, minute: 30)
        #expect(reminders.waterTimes == [ReminderTime(hour: 21, minute: 30)])
    }

    @Test func theWeighInComesOnceAWeekOnHerDay() throws {
        let calendar = try Self.warsaw()
        var data = Self.appData(turningOn: [.weighIn])
        let now = try Self.moment(Self.tuesday, 7, in: calendar)

        // Monday by default: the next one is on 16 November at 8:00.
        let planned = ReminderPlan.reminders(for: data, now: now, calendar: calendar)
        #expect(planned.map(\.day) == [LocalDate(year: 2026, month: 11, day: 16)])
        #expect(planned.first?.time == ReminderTime(hour: 8))

        data.settings.reminders.weighInWeekday = 2
        #expect(ReminderPlan.reminders(for: data, now: now, calendar: calendar).map(\.day) == [Self.tuesday])
        // She already weighed herself today: nothing more this week.
        data.setWeight(64.2, on: Self.tuesday)
        #expect(ReminderPlan.reminders(for: data, now: now, calendar: calendar).isEmpty)
    }

    @Test func theCycleNoteComesTwoDaysBeforeTheExpectedPeriod() throws {
        let calendar = try Self.warsaw()
        var data = Self.appData(turningOn: [.periodSoon])
        // Three periods of four days, 28 days apart: the next one is expected on 12 November.
        let starts = [LocalDate(year: 2026, month: 8, day: 20), LocalDate(year: 2026, month: 9, day: 17),
                      LocalDate(year: 2026, month: 10, day: 15)]
        for start in starts {
            for offset in 0..<4 {
                data.periodDays.insert(start.adding(days: offset))
            }
        }
        let engine = CycleEngine(periodDays: data.periodDays, today: Self.tuesday)
        let expected = try #require(engine.status(on: Self.tuesday).prediction?.expected)
        #expect(expected == LocalDate(year: 2026, month: 11, day: 12))

        let early = try Self.moment(Self.tuesday, 7, in: calendar)
        let planned = ReminderPlan.reminders(for: data, now: early, calendar: calendar)
        #expect(planned.map(\.day) == [Self.tuesday])
        #expect(planned.first?.time == ReminderTime(hour: 9))
        #expect(planned.first?.body.contains("nowy rozdział") == true)

        // After 9:00 it has passed; and with no periods marked there is nothing to expect.
        let late = try Self.moment(Self.tuesday, 10, in: calendar)
        #expect(ReminderPlan.reminders(for: data, now: late, calendar: calendar).isEmpty)
        data.periodDays = []
        #expect(ReminderPlan.reminders(for: data, now: early, calendar: calendar).isEmpty)
    }

    @Test func theDinnerQuestionIsSkippedOnceSheLoggedAnEveningMeal() throws {
        let calendar = try Self.warsaw()
        var data = Self.appData(turningOn: [.dinner])
        let now = try Self.moment(Self.tuesday, 18, in: calendar)
        #expect(ReminderPlan.reminders(for: data, now: now, calendar: calendar).count == 7)

        // A lunch doesn't count.
        let lunch = try Self.moment(Self.tuesday, 13, in: calendar)
        data.addMeal(MealEntry(createdAt: lunch, text: "zupa pomidorowa", parsed: ParsedMeal()), on: Self.tuesday)
        #expect(ReminderPlan.reminders(for: data, now: now, calendar: calendar).first?.day == Self.tuesday)

        // A meal logged after 16:00 does: only the next six evenings are left.
        let evening = try Self.moment(Self.tuesday, 17, 30, in: calendar)
        data.addMeal(MealEntry(createdAt: evening, text: "kanapka z serem", parsed: ParsedMeal()), on: Self.tuesday)
        let planned = ReminderPlan.reminders(for: data, now: now, calendar: calendar)
        #expect(planned.count == 6)
        #expect(planned.first?.day == Self.tuesday.adding(days: 1))
        #expect(planned.first?.time == ReminderTime(hour: 20))
        #expect(planned.first?.title == "dopisać kolację?")
    }

    @Test func aLetterDayGetsOneNoteWithoutAWordOfTheLetter() throws {
        let calendar = try Self.warsaw()
        var data = Self.appData(turningOn: [.letter])
        let written = Self.tuesday.adding(days: -90)
        let friday = Self.tuesday.adding(days: 3)
        data.letters = [
            Letter(writtenOn: written, opensOn: friday, text: "pamiętasz tamten spacer nad rzeką?"),
            Letter(writtenOn: written.adding(days: 1), opensOn: friday, text: "trzymam za Ciebie kciuki"),
            Letter(writtenOn: written, opensOn: Self.tuesday.adding(days: 30), text: "jeszcze nie teraz"),
            Letter(writtenOn: written, opensOn: Self.tuesday.adding(days: -1), text: "już otwarty"),
        ]
        let now = try Self.moment(Self.tuesday, 7, in: calendar)
        let planned = ReminderPlan.reminders(for: data, now: now, calendar: calendar)
        #expect(planned.count == 1)
        let note = try #require(planned.first)
        #expect(note.kind == .letter)
        #expect(note.day == friday)
        #expect(note.time == ReminderTime(hour: 9))
        for letter in data.letters {
            #expect(!note.title.contains(letter.text))
            #expect(!note.body.contains(letter.text))
        }
    }

    @Test func lockScreenWordsSayNothingExplicit() {
        let explicit = ["okres", "miesiącz", "krwaw", "menstru", "owulac", "cykl",
                        "wag", "waż", "kg", "kilogram", "kalori", "kcal"]
        for text in ReminderText.all {
            let words = (text.title + " " + text.body).lowercased()
            #expect(!words.isEmpty)
            for word in explicit {
                #expect(!words.contains(word), "„\(word)” on the lock screen: \(text.title) – \(text.body)")
            }
        }
    }

    @Test func everythingOnStaysInTheWeekInOrderAndUnderTheLimit() throws {
        let calendar = try Self.warsaw()
        var data = Self.appData(turningOn: ReminderKind.allCases)
        for offset in 0..<10 {
            data.letters.append(Letter(writtenOn: Self.tuesday.adding(days: -100),
                                       opensOn: Self.tuesday.adding(days: offset), text: "list \(offset)"))
        }
        let now = try Self.moment(Self.tuesday, 6, in: calendar)
        let planned = ReminderPlan.reminders(for: data, now: now, calendar: calendar)
        // 21 water, one weigh-in (Monday), 7 dinners and 7 letter days; no periods are marked.
        #expect(planned.count == 36)
        #expect(planned.count <= ReminderPlan.maximumCount)
        #expect(Set(planned.map(\.identifier)).count == planned.count)
        #expect(planned.allSatisfy { $0.date > now && $0.identifier.hasPrefix(ReminderPlan.identifierPrefix) })
        #expect(planned.map(\.date) == planned.map(\.date).sorted())
        let lastDay = Self.tuesday.adding(days: ReminderPlan.horizonDays - 1)
        #expect(planned.allSatisfy { $0.day >= Self.tuesday && $0.day <= lastDay })
        #expect(ReminderPlan.identifier(.weighIn, on: LocalDate(year: 2026, month: 3, day: 2),
                                        at: ReminderTime(hour: 8, minute: 5)) == "abouther.weighIn.2026-03-02.0805")
    }

    @Test func factsLookOnlyAtTheRemindersThatAreOn() throws {
        let calendar = try Self.warsaw()
        var data = AppData()
        data.addWater(WaterDay.goalGlasses, to: .midday, on: Self.tuesday)
        data.setWeight(64.0, on: Self.tuesday)
        data.letters = [Letter(writtenOn: Self.tuesday.adding(days: -30), opensOn: Self.tuesday, text: "x")]

        let off = ReminderPlan.Facts(data: data, today: Self.tuesday, calendar: calendar)
        #expect(!off.drankEnoughToday)
        #expect(!off.weighedInToday)
        #expect(off.letterDays.isEmpty)
        #expect(off.expectedPeriod == nil)

        data.settings.reminders.water.isOn = true
        data.settings.reminders.weighIn.isOn = true
        data.settings.reminders.letter.isOn = true
        let on = ReminderPlan.Facts(data: data, today: Self.tuesday, calendar: calendar)
        #expect(on.drankEnoughToday)
        #expect(on.weighedInToday)
        #expect(on.letterDays == [Self.tuesday])
        #expect(on != off)
    }
}
