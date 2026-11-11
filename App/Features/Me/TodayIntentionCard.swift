import SwiftUI
import AboutHerCore

/// Her intention for the day: one sentence, written in place. On "dziś" it is a line under the
/// greeting (`.inline`); at the top of "wnętrze" a card of its own (`.card`). A past day shows the
/// intention it had; without one it stays away.
struct TodayIntentionCard: View {
    enum Style {
        /// A card with the heading "intencja na dziś".
        case card
        /// Only the sentence, or "dopisz intencję na dziś" while there is none.
        case inline
    }

    @Environment(AppStore.self) private var store
    let day: LocalDate
    var style: Style = .card

    var body: some View {
        let intention = store.data.intention(on: day)
        let isToday = day == store.today
        if isToday || !intention.isEmpty {
            switch style {
            case .card:
                Card {
                    VStack(alignment: .leading, spacing: Spacing.item) {
                        SectionHeader(isToday ? "intencja na dziś" : "intencja · \(PolishDate.dayMonth(day))")
                        field(intention, emptyLine: "jedno zdanie, które poprowadzi Cię przez dzień")
                    }
                }
            case .inline:
                field(intention, emptyLine: "dopisz intencję na dziś")
            }
        }
    }

    private func field(_ intention: String, emptyLine: String) -> some View {
        InnerTextField(key: day,
                       text: intention,
                       placeholder: "np. dziś będę dla siebie łagodna",
                       emptyLine: emptyLine,
                       serif: true,
                       lines: 1...3,
                       deleteLabel: "usuń intencję",
                       save: { text, day in store.setIntention(text, on: day) },
                       delete: { day in store.setIntention("", on: day) })
    }
}
