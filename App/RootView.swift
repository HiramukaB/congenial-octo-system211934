import SwiftUI
import UIKit
import Combine
import AboutHerCore

nonisolated enum AppTab: String, Hashable {
    case today, calendar, food, movement, me

    /// UI tests open a tab directly with the launch arguments "-startTab calendar".
    static var initial: AppTab {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-startTab"),
              arguments.indices.contains(index + 1),
              let tab = AppTab(rawValue: arguments[index + 1])
        else { return .today }
        return tab
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = AppTab.initial
    /// The day "jedzenie" shows (0 = today, -1 = yesterday …). Kept here, so "otwórz jedzenie"
    /// on "dziś" can open the day she is looking at there.
    @State private var foodDayOffset = 0
    /// The welcome steps cover the tabs until she has finished them (`AppStore.needsOnboarding`).
    @State private var isShowingOnboarding = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("dziś", systemImage: "sun.max", value: AppTab.today) {
                TodayView(selectedTab: $selection, foodDayOffset: $foodDayOffset)
            }
            Tab("kalendarz", systemImage: "calendar", value: AppTab.calendar) {
                CalendarView()
            }
            Tab("jedzenie", systemImage: "fork.knife", value: AppTab.food) {
                FoodView(dayOffset: $foodDayOffset)
            }
            Tab("ruch", systemImage: "figure.yoga", value: AppTab.movement) {
                MovementView()
            }
            Tab("ja", systemImage: "sparkles", value: AppTab.me) {
                MeView()
            }
        }
        .tint(Palette.accent)
        // Always there: the tab bar never shrinks away while she scrolls.
        .tabBarMinimizeBehavior(.never)
        .onChange(of: scenePhase, initial: true) { oldPhase, phase in
            if phase == .active {
                store.refreshToday()
                NotificationScheduler.refresh(store)
            } else if oldPhase != phase {
                store.saveNow()
            }
        }
        // Her reminder settings, or what the reminders depend on, changed while the app is open.
        .onChange(of: NotificationScheduler.inputs(store)) {
            NotificationScheduler.refresh(store)
        }
        // Midnight (and time zone changes) while the app stays open.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.refreshToday()
        }
        .onChange(of: selection) { oldTab, newTab in
            // Leaving "jedzenie" brings it back to today, so the next meal never lands on another day.
            if oldTab == .food && newTab != .food {
                foodDayOffset = 0
            }
        }
        .onChange(of: store.today) {
            // A new day began: "jedzenie" starts again from today.
            foodDayOffset = 0
        }
        .onChange(of: store.needsOnboarding, initial: true) { _, needs in
            guard needs != isShowingOnboarding else { return }
            // In at once on launch, so the tabs never flash first; away with the usual slide.
            var transaction = Transaction()
            transaction.disablesAnimations = needs
            withTransaction(transaction) {
                isShowingOnboarding = needs
            }
        }
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            // A brand-new install, or her data from before the welcome existed: the steps show what
            // is already there. It closes when `store.completeOnboarding()` is called.
            OnboardingView()
                .problemAlert()
                .interactiveDismissDisabled()
        }
        // While the welcome covers the tabs (or is about to), its own alert speaks for the store.
        .problemAlert(isEnabled: !store.needsOnboarding && !isShowingOnboarding)
        // Face ID and the cover in the app switcher, over everything above.
        .appLock()
    }
}

extension View {
    /// "coś poszło nie tak": the store's problem, shown once wherever she is. RootView puts it on
    /// the tabs and on the welcome steps; `isEnabled` keeps the tabs' one quiet while the welcome
    /// covers them.
    func problemAlert(isEnabled: Bool = true) -> some View {
        modifier(ProblemAlert(isEnabled: isEnabled))
    }
}

private struct ProblemAlert: ViewModifier {
    @Environment(AppStore.self) private var store
    let isEnabled: Bool
    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .onChange(of: store.problem, initial: true) { _, problem in
                isShowing = isEnabled && problem != nil
            }
            .onChange(of: isEnabled) { _, enabled in
                isShowing = enabled && store.problem != nil
            }
            .alert("coś poszło nie tak", isPresented: $isShowing) {
                Button("rozumiem", role: .cancel) {
                    store.problem = nil
                }
            } message: {
                Text(store.problem ?? "")
            }
    }
}
