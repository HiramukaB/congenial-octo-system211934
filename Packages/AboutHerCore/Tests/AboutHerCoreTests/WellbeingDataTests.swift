import Foundation
import Testing
@testable import AboutHerCore

@Suite("Symptoms, inner self, movement and settings in her file")
struct WellbeingDataTests {
    /// The shape 0.1.9 writes (schema 2): periods and food only. Made-up values.
    private static let schema2File = Data(#"""
    {
      "meals" : {
        "2026-03-02" : [
          {
            "createdAt" : "2026-03-02T07:45:00Z",
            "id" : "6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C",
            "items" : [],
            "text" : "coś słodkiego",
            "totals" : { "carbs" : 0, "fat" : 0, "kcal" : 0, "protein" : 0 },
            "unknown" : [ "coś słodkiego" ]
          }
        ]
      },
      "nutritionProfile" : {
        "activity" : "light",
        "birthYear" : 1990,
        "deficitKcal" : 300,
        "heightCm" : 170,
        "weightKg" : 65
      },
      "periodDays" : [ "2026-02-20", "2026-02-21" ],
      "schemaVersion" : 2,
      "targetsSetting" : { "mode" : "automatic" },
      "userFoods" : [],
      "water" : { "2026-03-02" : { "evening" : 0, "midday" : 2, "morning" : 3 } },
      "weights" : { "2026-03-02" : 64.9 }
    }
    """#.utf8)

    @Test func aSchema2FileLoadsWithEveryNewFieldEmpty() throws {
        #expect(!AppDataCoding.isFromNewerVersion(Self.schema2File))
        let appData = try AppDataCoding.decode(Self.schema2File)
        let day = LocalDate(year: 2026, month: 3, day: 2)
        #expect(appData.periodDays.count == 2)
        #expect(appData.meals(on: day).count == 1)
        #expect(appData.weights[day] == 64.9)
        #expect(appData.nutritionProfile?.birthYear == 1990)

        #expect(appData.symptoms.isEmpty)
        #expect(appData.intentions.isEmpty)
        #expect(appData.wins.isEmpty)
        #expect(appData.manifest.isEmpty)
        #expect(appData.reflections.isEmpty)
        #expect(appData.letters.isEmpty)
        #expect(appData.photos.isEmpty)
        #expect(appData.moments.isEmpty)
        #expect(appData.workouts.isEmpty)
        #expect(appData.training == TrainingProgress())
        #expect(appData.training.stage == 1)
        #expect(appData.training.stageOfferAnsweredOn == nil)
        #expect(appData.settings == AppSettings())
        #expect(!appData.settings.isLockEnabled)
        let reminders = appData.settings.reminders
        #expect([reminders.water, reminders.weighIn, reminders.periodSoon, reminders.dinner, reminders.letter]
                    .allSatisfy { !$0.isOn })
        // Schema 4: no name, the welcome not finished yet, no humor.
        #expect(appData.settings.onboarding == OnboardingState())
        #expect(!appData.settings.onboarding.isCompleted)
        #expect(appData.settings.onboarding.name == nil)
        #expect(appData.humor.isEmpty)

        // Saved again, it is a file of the current schema that reads back the same.
        let written = try AppDataCoding.encode(appData)
        #expect(!AppDataCoding.isFromNewerVersion(written))
        var current = appData
        current.schemaVersion = AppData.currentSchemaVersion
        #expect(try AppDataCoding.decode(written) == current)
    }

    @Test func everyNewFieldRoundTrips() throws {
        let wednesday = LocalDate(year: 2026, month: 3, day: 4)
        var appData = AppData()
        appData.setSymptoms(SymptomDay(energy: 2, mood: 5, sleep: 8, appetite: 9,
                                       flags: [.headache, .bloating]), on: wednesday)
        appData.setSymptoms(SymptomDay(flags: [.cramps]), on: wednesday.adding(days: -1))
        appData.setIntention("dziś idę swoim tempem", on: wednesday)
        appData.wins = [SmallWin(day: wednesday, text: "spacer mimo deszczu")]
        appData.manifest = "Buduję spokój, dzień po dniu."
        appData.setReflection(WeeklyReflection(question: "co dało Ci energię?", answer: "poranne słońce"),
                              forWeekOf: wednesday)
        appData.letters = [Letter(writtenOn: wednesday, opensOn: Letter.defaultOpeningDay(writtenOn: wednesday),
                                  text: "cześć, to ja z marca")]
        appData.photos = [ProgressPhoto(day: wednesday)]
        appData.moments = [
            MomentNote(day: wednesday, kind: .answer, prompt: "co dziś było dobre?", text: "ciepła herbata"),
            MomentNote(day: wednesday, kind: .intention, prompt: "", text: "oddycham spokojnie"),
        ]
        appData.addWorkout(Workout(kind: .walk, minutes: 30), on: wednesday)
        appData.addWorkout(Workout(kind: .yoga, minutes: 15), on: wednesday)
        appData.training = TrainingProgress(stage: 2, stageOfferAnsweredOn: wednesday)
        var settings = AppSettings(isLockEnabled: true)
        settings.reminders.water.isOn = true
        settings.reminders.dinner = ReminderSetting(isOn: true, time: ReminderTime(hour: 19, minute: 30))
        settings.reminders.weighInWeekday = 1
        appData.settings = settings

        let encoded = try AppDataCoding.encode(appData)
        #expect(!AppDataCoding.isFromNewerVersion(encoded))
        let decoded = try AppDataCoding.decode(encoded)
        #expect(decoded == appData)
        // The reflection is kept under the Monday of its week.
        #expect(Array(decoded.reflections.keys) == [LocalDate(year: 2026, month: 3, day: 2)])
        #expect(decoded.symptoms(on: wednesday).flags == Set([SymptomFlag.bloating, .headache]))
        #expect(decoded.workouts(on: wednesday).map(\.kind) == [WorkoutKind.walk, .yoga])

        // Flags are written in a fixed order, so backups compare cleanly.
        let json = String(decoding: encoded, as: UTF8.self)
        let bloating = try #require(json.range(of: "\"bloating\""))
        let headache = try #require(json.range(of: "\"headache\""))
        #expect(bloating.lowerBound < headache.lowerBound)
    }

    @Test func filesFromANewerVersionStayReadOnly() {
        let newer = AppData.currentSchemaVersion + 1
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":\#(newer),"periodDays":[]}"#.utf8)))
        #expect(AppDataCoding.isFromNewerVersion(Data(#"{"schemaVersion":3,"periodDays":[],"sleepLog":{}}"#.utf8)))
        // A value only a newer version knows, deep inside: the file can't be decoded, so it stays read-only.
        #expect(AppDataCoding.isFromNewerVersion(
            Data(#"{"schemaVersion":3,"symptoms":{"2026-03-02":{"flags":["nowy"]}}}"#.utf8)))
        #expect(AppDataCoding.isFromNewerVersion(Data(#"""
        {"schemaVersion":3,"workouts":{"2026-03-02":[{"id":"6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C","kind":"climbing","minutes":20}]}}
        """#.utf8)))
        // This version's own fields are known.
        #expect(!AppDataCoding.isFromNewerVersion(
            Data(#"{"schemaVersion":3,"symptoms":{},"settings":{"isLockEnabled":true}}"#.utf8)))
    }

    @Test func emptyDaysAreNotKept() {
        let day = LocalDate(year: 2026, month: 3, day: 2)
        var appData = AppData()
        appData.setSymptoms(SymptomDay(mood: 7), on: day)
        #expect(appData.symptoms[day] != nil)
        var cleared = appData.symptoms(on: day)
        cleared.mood = nil
        appData.setSymptoms(cleared, on: day)
        #expect(appData.symptoms.isEmpty)

        appData.setIntention("spokojnie", on: day)
        #expect(appData.intention(on: day) == "spokojnie")
        appData.setIntention("  ", on: day)
        #expect(appData.intentions.isEmpty)

        let walk = Workout(kind: .walk, minutes: 30)
        appData.addWorkout(walk, on: day)
        let yoga = Workout(id: walk.id, kind: .yoga, minutes: 20)
        appData.updateWorkout(yoga, on: day)
        #expect(appData.workouts(on: day) == [yoga])
        appData.updateWorkout(Workout(kind: .dance, minutes: 10), on: day)
        #expect(appData.workouts(on: day) == [yoga])
        appData.removeWorkout(id: walk.id, on: day)
        #expect(appData.workouts.isEmpty)

        appData.setReflection(WeeklyReflection(question: "pytanie", answer: "odpowiedź"), forWeekOf: day)
        // Sunday of the same week: the same reflection, now emptied.
        appData.setReflection(WeeklyReflection(question: "pytanie", answer: " "), forWeekOf: day.adding(days: 6))
        #expect(appData.reflections.isEmpty)
    }

    @Test func weeksStartOnMondayAndValuesStayInRange() throws {
        let monday = LocalDate(year: 2026, month: 3, day: 2)
        #expect(monday.startOfWeek == monday)
        #expect(LocalDate(year: 2026, month: 3, day: 4).startOfWeek == monday)
        #expect(LocalDate(year: 2026, month: 3, day: 8).startOfWeek == monday)
        #expect(LocalDate(year: 2026, month: 3, day: 9).startOfWeek == LocalDate(year: 2026, month: 3, day: 9))

        #expect(ReminderTime(hour: 25, minute: -5) == ReminderTime(hour: 23, minute: 0))
        #expect(ReminderTime(hour: 7, minute: 30) < ReminderTime(hour: 8))
        #expect(ReminderSettings(weighInWeekday: 9).weighInWeekday == 7)
        #expect(TrainingProgress(stage: 7).stage == 3)
        #expect(try AppDataCoding.decode(Data(#"{"training":{"stage":0}}"#.utf8)).training.stage == 1)

        // Three months later, or the last day of a shorter month.
        #expect(Letter.defaultOpeningDay(writtenOn: LocalDate(year: 2026, month: 11, day: 30))
                == LocalDate(year: 2027, month: 2, day: 28))
        let letter = Letter(writtenOn: monday, opensOn: monday.adding(days: 10), text: "x")
        #expect(!letter.isOpen(on: monday.adding(days: 9)))
        #expect(letter.isOpen(on: monday.adding(days: 10)))

        let id = try #require(UUID(uuidString: "6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C"))
        #expect(ProgressPhoto(id: id, day: monday).fileName == "6F1C3E2A-8B4D-4C5E-9A7F-1D2E3F4A5B6C.jpg")
    }
}
