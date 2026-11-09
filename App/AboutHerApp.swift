import SwiftUI

@main
struct AboutHerApp: App {
    @State private var store = AppStore.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
