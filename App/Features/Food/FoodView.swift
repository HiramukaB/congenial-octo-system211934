import SwiftUI
import AboutHerCore

/// "jedzenie": her daily nutrition notebook – balance, meals, water and weight for the chosen day.
/// The meal card names the day whenever it isn't today, and leaving this tab brings it back to
/// today, so nothing is logged to another day by surprise.
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
                Text("jedzenie").screenTitle()
                DaySwitcher(date: day,
                            isToday: dayOffset == 0,
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
                Text(polish: "wszystkie wartości są orientacyjne – to szacunek, nie dokładny pomiar")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
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
