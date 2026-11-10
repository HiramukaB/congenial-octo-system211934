import Foundation
import Testing
@testable import AboutHerCore

@Suite("Her inner notes: the question of the week and the order things are shown in")
struct InnerTests {
    @Test func aWeekKeepsItsQuestionAndTheNextWeekBringsTheNextOne() {
        let monday = LocalDate(year: 2026, month: 11, day: 9)
        #expect(monday.isoWeekday == 1)
        let question = WeeklyReflection.question(forWeekOf: monday)
        #expect(WeeklyReflection.questions.contains(question))
        for offset in 0..<7 {
            #expect(WeeklyReflection.question(forWeekOf: monday.adding(days: offset)) == question)
        }
        #expect(WeeklyReflection.question(forWeekOf: monday.adding(days: 7)) != question)
        #expect(WeeklyReflection.question(forWeekOf: monday.adding(days: -1)) != question)

        // Every question comes in turn, then it starts over.
        let count = WeeklyReflection.questions.count
        let weeks = (0..<count).map { WeeklyReflection.question(forWeekOf: monday.adding(days: 7 * $0)) }
        #expect(Set(weeks) == Set(WeeklyReflection.questions))
        #expect(WeeklyReflection.question(forWeekOf: monday.adding(days: 7 * count)) == question)
    }

    @Test func winsAndPhotosShowTheNewestFirst() {
        let day = LocalDate(year: 2026, month: 3, day: 4)
        let older = SmallWin(day: day.adding(days: -3), text: "spacer po pracy")
        let first = SmallWin(day: day, text: "śniadanie bez pośpiechu")
        let second = SmallWin(day: day, text: "woda do południa")
        var appData = AppData()
        // An older day written down last.
        appData.wins = [first, second, older]
        #expect(appData.winsNewestFirst == [second, first, older])

        let earlier = ProgressPhoto(day: day.adding(days: -40))
        let morning = ProgressPhoto(day: day)
        let evening = ProgressPhoto(day: day)
        appData.photos = [morning, earlier, evening]
        #expect(appData.photosNewestFirst == [evening, morning, earlier])
    }

    @Test func lettersOpenOnTheirDayAndTheSealedOnesComeSoonestFirst() {
        let today = LocalDate(year: 2026, month: 11, day: 10)
        let opensToday = Letter(writtenOn: today.addingMonths(-3), opensOn: today, text: "cześć z sierpnia")
        let openedEarlier = Letter(writtenOn: today.addingMonths(-6), opensOn: today.adding(days: -30),
                                   text: "cześć z maja")
        let opensTomorrow = Letter(writtenOn: today.adding(days: -1), opensOn: today.adding(days: 1),
                                   text: "cześć z wczoraj")
        let opensLater = Letter(writtenOn: today.adding(days: -20), opensOn: today.addingMonths(3),
                                text: "cześć z października")
        var appData = AppData()
        appData.letters = [opensLater, openedEarlier, opensTomorrow, opensToday]

        #expect(appData.openLetters(on: today) == [opensToday, openedEarlier])
        #expect(appData.sealedLetters(on: today) == [opensTomorrow, opensLater])
        // The next day the first sealed one is open too, and comes first.
        #expect(appData.openLetters(on: today.adding(days: 1)) == [opensTomorrow, opensToday, openedEarlier])
        #expect(appData.sealedLetters(on: today.adding(days: 1)) == [opensLater])
    }

    @Test func pastReflectionsLeaveOutThisWeekAndStartWithTheLatest() {
        let wednesday = LocalDate(year: 2026, month: 11, day: 11)
        var appData = AppData()
        appData.setReflection(WeeklyReflection(question: "co dało Ci energię?", answer: "ten tydzień"),
                              forWeekOf: wednesday)
        appData.setReflection(WeeklyReflection(question: "z czego jesteś dumna?", answer: "miesiąc temu"),
                              forWeekOf: wednesday.adding(days: -30))
        appData.setReflection(WeeklyReflection(question: "co możesz odpuścić?", answer: "tydzień temu"),
                              forWeekOf: wednesday.adding(days: -7))

        let past = appData.pastReflections(before: wednesday)
        #expect(past.map { $0.reflection.answer } == ["tydzień temu", "miesiąc temu"])
        #expect(past.map { $0.week } == [LocalDate(year: 2026, month: 11, day: 2),
                                         LocalDate(year: 2026, month: 10, day: 12)])
        // Asked on the Monday of the week, the same weeks count as past.
        #expect(appData.pastReflections(before: LocalDate(year: 2026, month: 11, day: 9)).count == 2)
        #expect(appData.pastReflections(before: LocalDate(year: 2026, month: 11, day: 16)).count == 3)
    }
}
