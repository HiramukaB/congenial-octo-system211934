import Foundation
import AboutHerCore

extension DemoData {
    /// An answer to a question card two days ago and her own intention for today – made up.
    static func addMoment(to data: inout AppData, today: LocalDate) {
        data.moments.append(MomentNote(day: today.adding(days: -2), kind: .answer,
                                       prompt: "jaki drobiazg potrafi poprawić Ci cały dzień?",
                                       text: "kubek ciepłej herbaty i pięć minut ciszy przy oknie"))
        data.moments.append(MomentNote(day: today, kind: .intention, prompt: "",
                                       text: "pozwalam sobie dziś zwolnić"))
    }
}
