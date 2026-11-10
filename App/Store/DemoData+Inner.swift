import AboutHerCore

extension DemoData {
    /// A made-up intention, two small wins, the manifest, last week's reflection, one letter still
    /// sealed and one already open; no photos.
    static func addInner(to data: inout AppData, today: LocalDate) {
        data.setIntention("dziś jestem dla siebie łagodna", on: today)
        data.wins = [
            SmallWin(day: today.adding(days: -2), text: "wyszłam na spacer, choć padało"),
            SmallWin(day: today, text: "zjadłam spokojnie śniadanie, bez telefonu"),
        ]
        data.manifest = "Jestem dla siebie dobra i cierpliwa. Robię małe kroki, dzień po dniu."
        data.setReflection(WeeklyReflection(question: "co w tym tygodniu dało Ci najwięcej energii?",
                                            answer: "poranne spacery i wcześniejsze chodzenie spać"),
                           forWeekOf: today.adding(days: -7))
        let written = today.adding(days: -20)
        let writtenEarlier = today.adding(days: -100)
        data.letters = [
            Letter(writtenOn: written, opensOn: Letter.defaultOpeningDay(writtenOn: written),
                   text: "Cześć, to ja sprzed trzech miesięcy. Mam nadzieję, że jesteś dla siebie dobra."),
            Letter(writtenOn: writtenEarlier, opensOn: Letter.defaultOpeningDay(writtenOn: writtenEarlier),
                   text: "Cześć! Pamiętasz, jak zaczynałaś? Cokolwiek się wydarzyło, jestem z Ciebie dumna."),
        ]
    }
}
