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
    @State private var isShowingProblem = false

    var body: some View {
        TabView(selection: $selection) {
            Tab("dziś", systemImage: "sun.max", value: AppTab.today) {
                TodayView(selectedTab: $selection)
            }
            Tab("kalendarz", systemImage: "calendar", value: AppTab.calendar) {
                CalendarView()
            }
            Tab("jedzenie", systemImage: "fork.knife", value: AppTab.food) {
                FoodView()
            }
            Tab("ruch", systemImage: "figure.yoga", value: AppTab.movement) {
                MovementView()
            }
            Tab("ja", systemImage: "sparkles", value: AppTab.me) {
                MeView()
            }
        }
        .tint(Palette.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        .onChange(of: scenePhase, initial: true) { oldPhase, phase in
            if phase == .active {
                store.refreshToday()
            } else if oldPhase != phase {
                store.saveNow()
            }
        }
        // Midnight (and time zone changes) while the app stays open.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.refreshToday()
        }
        .onChange(of: store.problem, initial: true) { _, problem in
            isShowingProblem = problem != nil
        }
        .alert("coś poszło nie tak", isPresented: $isShowingProblem) {
            Button("rozumiem", role: .cancel) {
                store.problem = nil
            }
        } message: {
            Text(store.problem ?? "")
        }
    }
}
