import Foundation
import AboutHerCore

/// Her first steps: the name she wants to be called by, the welcome steps and the short guide.
extension AppStore {
    // MARK: - Reading

    /// The welcome steps should show: her data has been read and can be changed, and she hasn't
    /// finished them yet. Never while her file is unread or read-only, and never with
    /// `-skipOnboarding` or the plain demo (`LaunchArguments`).
    var needsOnboarding: Bool {
        // `isEditable` isn't observed. Her data becomes editable together with a new `data`, or –
        // when her file is missing and no copy can be read – with only `problem` set. Both are
        // read first, so a view asking this is redrawn in either case.
        _ = problem
        let isCompleted = data.settings.onboarding.isCompleted
        guard !LaunchArguments.skipsOnboarding, isEditable else { return false }
        return !isCompleted
    }

    /// The name she wants to be called by; nil when she left it empty.
    var preferredName: String? {
        data.settings.onboarding.name
    }

    /// She has seen (or skipped) the short guide.
    var hasSeenTutorial: Bool {
        data.settings.onboarding.hasSeenTutorial
    }

    /// Her data already holds something she logged – an update meets the welcome, not a new
    /// install – so the first step greets her as someone the app already knows.
    var hasHistoryBeforeWelcome: Bool {
        !data.periodDays.isEmpty || !data.meals.isEmpty || !data.weights.isEmpty
            || data.nutritionProfile != nil || !data.symptoms.isEmpty || !data.workouts.isEmpty
    }

    // MARK: - Changes

    /// Saves the name she wants to be called by; an empty one removes it.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func setPreferredName(_ name: String) -> Bool {
        let cleaned = OnboardingState.cleanName(name)
        return change { $0.settings.onboarding.name = cleaned }
    }

    /// She finished the welcome steps: they don't show again. Returns `false` when nothing was saved.
    @discardableResult
    func completeOnboarding() -> Bool {
        let now = Date.now
        return change { appData in
            if appData.settings.onboarding.completedAt == nil {
                appData.settings.onboarding.completedAt = now
            }
        }
    }

    /// She has seen the short guide (or skipped it); with `false` it counts as unseen again.
    @discardableResult
    func setTutorialSeen(_ seen: Bool = true) -> Bool {
        change { $0.settings.onboarding.hasSeenTutorial = seen }
    }

    /// Marks her last period in one go: `days` days from `start`, the days after today left out.
    /// Days already marked stay. Returns `false` when nothing was saved.
    @discardableResult
    func markPeriod(startingOn start: LocalDate, days: Int) -> Bool {
        let today = self.today
        guard start <= today, days >= 1 else { return false }
        return change { appData in
            _ = appData.markPeriodDays(from: start, count: days, today: today)
        }
    }

    /// The welcome's cycle step, as she answers it: `days` days from `start` – at most two weeks,
    /// never after today – marked like the calendar marks them. First it takes back `earlier`, the
    /// days her previous answer marked, so a corrected answer leaves nothing behind; days she
    /// marked herself always stay. With `start` nil it only takes them back.
    ///
    /// Returns the days it newly marked (the next answer's `earlier`), or nil when nothing could be
    /// saved – she is told why.
    func markWelcomePeriod(startingOn start: LocalDate?, days: Int, replacing earlier: Set<LocalDate>) -> Set<LocalDate>? {
        let today = self.today
        var added: Set<LocalDate> = []
        let saved = change { appData in
            added = appData.markPeriodDays(from: start, count: days, today: today, replacing: earlier)
        }
        return saved ? added : nil
    }
}
