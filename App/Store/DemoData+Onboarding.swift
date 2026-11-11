import Foundation
import AboutHerCore

extension DemoData {
    /// The made-up Ola finished the welcome a few weeks ago and has seen the guide.
    /// ("-showOnboarding" opens the welcome on top of this data anyway: `AppStore.makeDefault`.)
    static func addOnboarding(to data: inout AppData, now: Date) {
        data.settings.onboarding = OnboardingState(name: "Ola",
                                                   completedAt: now.addingTimeInterval(-30 * 24 * 60 * 60),
                                                   hasSeenTutorial: true)
    }
}
