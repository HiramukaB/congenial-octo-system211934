import SwiftUI
import AboutHerCore

/// "jedzenie": her daily nutrition notebook – the balance, her meals, water and weight for the
/// chosen day. The cards she logs in name the day whenever it isn't today, and leaving this tab
/// brings it back to today, so nothing is logged to another day by surprise.
struct FoodView: View {
    @Environment(AppStore.self) private var store
    /// 0 = today, -1 = yesterday … RootView keeps it, so "otwórz jedzenie" on "dziś" opens the day
    /// she is looking at there, and leaving this tab brings it back to today.
    @Binding var dayOffset: Int
    @State private var teachRequest: TeachRequest? = nil
    @State private var isEditingTargets = false

    var body: some View {
        let today = store.today
        let day = today.adding(days: dayOffset)
        // Around the screen's scroll view, so the meal field can keep itself above the keyboard.
        ScrollViewReader { scroll in
            Screen(tint: store.cycle.phase(on: day, today: today)?.phase.tint) {
                FoodHeader(day: day,
                           offset: dayOffset,
                           onPrevious: { dayOffset -= 1 },
                           onNext: { dayOffset = min(0, dayOffset + 1) },
                           onToday: { dayOffset = 0 })
                BalanceCard(day: day, onEditTargets: { isEditingTargets = true })
                MealLogCard(day: day,
                            onTeach: { teachRequest = TeachRequest(name: $0) },
                            onEditFood: { teachRequest = TeachRequest(name: $0.name, existing: $0) },
                            keepEditorInSight: { scroll.scrollTo(MealLogCard.editorID, anchor: .bottom) })
                WaterCard(day: day)
                WeightCard(day: day)
                Text(polish: "wszystkie wartości są orientacyjne")
                    .hintText()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $teachRequest) { request in
            TeachFoodSheet(suggestedName: request.name, existing: request.existing)
        }
        .sheet(isPresented: $isEditingTargets) {
            NutritionProfileSheet()
        }
    }
}

/// Which product she wants to teach the app: an unknown one from "nie znam jeszcze", or one of
/// her own (`existing`) to correct.
struct TeachRequest: Identifiable {
    let name: String
    var existing: FoodItem?
    var id: String { existing?.id ?? name }
}

/// The title and the day it shows, as one block: "jedzenie", then the day between the round
/// arrows that switch days (the same ones as on "dziś"). On an earlier day "wróć do dziś" sits
/// next to the title.
private struct FoodHeader: View {
    let day: LocalDate
    let offset: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
                Text("jedzenie")
                    .screenTitle()
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if offset != 0 {
                    Button("wróć do dziś", action: onToday)
                        .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
                }
            }
            HStack(spacing: Spacing.tight) {
                ChevronStepButton(systemImage: "chevron.left", label: "poprzedni dzień", action: onPrevious)
                dayName
                    .frame(maxWidth: .infinity)
                ChevronStepButton(systemImage: "chevron.right", label: "następny dzień",
                                  isEnabled: offset < 0, action: onNext)
            }
        }
        .padding(.bottom, Spacing.hairline)
    }

    /// "dziś · wtorek, 10 listopada" on one line; in two when it doesn't fit.
    private var dayName: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                relativeWord
                dateText
            }
            VStack(spacing: 2) {
                relativeWord
                dateText
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var relativeWord: some View {
        if let word = relativeName {
            Text(word)
                .displayFont(19, italic: true, relativeTo: .title3)
                .foregroundStyle(Palette.accent)
        }
    }

    /// Next to "dziś" or "wczoraj" the date is the quieter part; alone it is the day's name.
    private var dateText: some View {
        let isAlone = relativeName == nil
        return Text(PolishDate.long(day))
            .font(isAlone ? Font.body : Font.subheadline)
            .foregroundStyle(isAlone ? Palette.text : Palette.text2)
    }

    private var relativeName: String? {
        switch offset {
        case 0: "dziś"
        case -1: "wczoraj"
        case -2: "przedwczoraj"
        default: nil
        }
    }
}
