import AboutHerCore

extension DemoData {
    /// Made-up symptoms for today, yesterday and a brighter day earlier in the week.
    static func addSymptoms(to data: inout AppData, today: LocalDate) {
        data.setSymptoms(SymptomDay(energy: .medium, mood: .good, sleep: .okay, appetite: .normal,
                                    flags: [.bloating]),
                         on: today)
        data.setSymptoms(SymptomDay(energy: .low, mood: .neutral, sleep: .poor, flags: [.cramps, .drowsiness]),
                         on: today.adding(days: -1))
        data.setSymptoms(SymptomDay(energy: .high, mood: .veryGood, sleep: .good),
                         on: today.adding(days: -4))
    }
}
