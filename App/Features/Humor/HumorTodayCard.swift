import SwiftUI
import AboutHerCore

/// On "dziś": one of her jokes or quotes, to make her smile – only on today, only when she has
/// some, and only when today asks for it: her mood is low (1–4), or she hasn't marked it and it
/// is late in the day (`HumorNudge`). Otherwise it shows nothing at all, not even a gap.
///
/// It shows the day's one (`AppData.humorItem(for:)`); "coś innego" draws another.
struct HumorTodayCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate
    /// The one she drew with "coś innego", and the day she drew it on.
    @State private var pick: HumorTodayPick? = nil

    init(day: LocalDate) {
        self.day = day
    }

    var body: some View {
        let humor = store.data.humor
        let mood = store.data.symptoms(on: day).mood
        let hour = Calendar.current.component(.hour, from: Date())
        if day == store.today,
           HumorNudge.offersSmile(mood: mood, hour: hour, hasHumor: !humor.isEmpty),
           let item = shownItem(in: humor) {
            Card {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    SectionHeader("coś na uśmiech")
                    HumorQuoteText(item: item, size: 19, detail: HumorFormat.attribution(item))
                        .accessibilityElement(children: .combine)
                        .id(item.id)
                        .transition(.opacity)
                    if humor.count > 1 {
                        StarActionButton("coś innego", size: .regular) {
                            drawAnother(after: item.id)
                        }
                    }
                }
            }
            .transition(.opacity)
        }
    }

    /// The one she drew today, while it is still there; otherwise the day's one.
    private func shownItem(in humor: [HumorItem]) -> HumorItem? {
        if let pick = pick, pick.day == day, let item = humor.first(where: { $0.id == pick.id }) {
            return item
        }
        return store.data.humorItem(for: day)
    }

    private func drawAnother(after id: UUID) {
        guard let next = store.data.randomHumor(after: id) else { return }
        withAnimation(.smooth) {
            pick = HumorTodayPick(day: day, id: next.id)
        }
    }
}

/// A joke or quote drawn on "dziś", for the day it was drawn on.
private nonisolated struct HumorTodayPick {
    let day: LocalDate
    let id: UUID
}
