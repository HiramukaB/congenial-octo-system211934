import SwiftUI
import AboutHerCore

/// "jedzenie": her daily nutrition notebook – balance, meals, water and weight for the chosen day.
/// The day switcher is always visible, so nothing is ever logged to another day by surprise.
struct FoodView: View {
    @Environment(AppStore.self) private var store
    @State private var dayOffset = 0
    @State private var teachRequest: TeachRequest?
    @State private var isEditingTargets = false

    var body: some View {
        let today = store.today
        let day = today.adding(days: dayOffset)
        Screen(tint: store.cycle.phase(on: day, today: today)?.phase.tint) {
            Text("jedzenie").screenTitle()
            DaySwitcher(date: day,
                        isToday: dayOffset == 0,
                        onPrevious: { dayOffset -= 1 },
                        onNext: { dayOffset = min(0, dayOffset + 1) },
                        onToday: { dayOffset = 0 })
            BalanceCard(day: day, onEditTargets: { isEditingTargets = true })
            MealLogCard(day: day, onTeach: { teachRequest = TeachRequest(name: $0) })
            WaterCard(day: day)
            WeightCard(day: day)
            Text(polish: "wszystkie wartości są orientacyjne – to szacunek, nie dokładny pomiar")
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .onChange(of: store.today) {
            dayOffset = 0
        }
        .sheet(item: $teachRequest) { request in
            TeachFoodSheet(suggestedName: request.name)
        }
        .sheet(isPresented: $isEditingTargets) {
            NutritionProfileSheet()
        }
    }
}

/// Which unknown product she wants to teach the app.
struct TeachRequest: Identifiable {
    let name: String
    var id: String { name }
}
