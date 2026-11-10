import AboutHerCore

extension DemoData {
    /// Made-up scales (1–10) and symptoms for today, yesterday and a brighter day earlier in the week.
    static func addSymptoms(to data: inout AppData, today: LocalDate) {
        data.setSymptoms(SymptomDay(energy: 6, mood: 7, sleep: 6, appetite: 5, flags: [.bloating]),
                         on: today)
        data.setSymptoms(SymptomDay(energy: 3, mood: 5, sleep: 4, flags: [.cramps, .drowsiness]),
                         on: today.adding(days: -1))
        data.setSymptoms(SymptomDay(energy: 8, mood: 9, sleep: 8),
                         on: today.adding(days: -4))
    }
}
