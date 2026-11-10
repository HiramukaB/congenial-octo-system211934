import SwiftUI
import AboutHerCore

/// "intencja na dziś" on "dziś" and at the top of "wnętrze": one sentence for the day, written in
/// place. A past day shows the intention it had; without one the card stays away.
struct TodayIntentionCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate

    var body: some View {
        let intention = store.data.intention(on: day)
        let isToday = day == store.today
        if isToday || !intention.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isToday ? Self.todayTitle : "intencja · \(PolishDate.dayMonth(day))")
                        .sectionTitle()
                    InnerTextField(key: day,
                                   text: intention,
                                   placeholder: "np. dziś będę dla siebie łagodna",
                                   emptyLine: "jedno zdanie, które poprowadzi Cię przez dzień – dotknij, żeby je zapisać",
                                   serif: true,
                                   lines: 1...3,
                                   deleteLabel: "usuń intencję",
                                   save: { text, day in store.setIntention(text, on: day) },
                                   delete: { day in store.setIntention("", on: day) })
                }
            }
        }
    }

    private static let todayTitle = "intencja na dziś"
}
