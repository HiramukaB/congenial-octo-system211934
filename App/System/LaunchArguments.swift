import Foundation

/// What UI tests and screenshots ask for with launch arguments. Her phone never passes any.
///
/// - `-demoData`: a fictional history kept only in memory; nothing is saved, no Face ID, no
///   reminders. The welcome steps count as done, so screenshots show the tabs.
/// - `-showOnboarding`: the welcome steps on top of that same demo data (it implies `-demoData`),
///   for screenshots of the welcome.
/// - `-skipOnboarding`: the welcome steps never show – for UI tests on real storage, which start
///   on a fresh simulator. Nothing about it is written to her data.
///
/// `-startTab` and `-stillBackground` are read where they are used (`AppTab`, `AmbientBackground`).
nonisolated enum LaunchArguments {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// The welcome steps show on demo data, whatever her data says.
    static let showsOnboarding = arguments.contains("-showOnboarding")

    /// A fictional history kept only in memory.
    static let usesDemoData = arguments.contains("-demoData") || showsOnboarding

    /// The welcome steps never show: UI tests, and the demo unless `-showOnboarding` asks for them.
    static let skipsOnboarding = !showsOnboarding
        && (arguments.contains("-skipOnboarding") || arguments.contains("-demoData"))
}
