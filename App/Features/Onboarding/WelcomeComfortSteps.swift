import SwiftUI
import AboutHerCore

/// "o czym mam Ci przypominać?": three reminders to start with, one tap each, at the times
/// "ustawienia" suggests. The first one she turns on asks iOS whether the app may send
/// notifications, as in "ustawienia"; her choice is kept even if she says no.
struct WelcomeRemindersStep: View {
    @Environment(AppStore.self) private var store
    let onBack: () -> Void
    let onNext: () -> Void

    /// What iOS says about notifications; nil until it has been asked (and always in the demo).
    @State private var permission: ReminderPermission? = nil
    @State private var isAsking = false

    private static let kinds: [ReminderKind] = [.water, .weighIn, .periodSoon]

    var body: some View {
        let reminders = store.data.settings.reminders
        let isAnyOn = Self.kinds.contains { reminders[$0].isOn }
        WelcomePage(step: .reminders,
                    title: "o czym mam Ci przypominać?",
                    subtitle: "tylko o tym, co wybierzesz – godziny zmienisz w ustawieniach",
                    canSkip: !isAnyOn,
                    onBack: onBack,
                    onNext: onNext) {
            VStack(alignment: .leading, spacing: Spacing.group) {
                TileGrid(columns: 1) {
                    ForEach(Self.kinds, id: \.self) { kind in
                        ToggleTile(title: title(of: kind, in: reminders), isOn: reminders[kind].isOn) {
                            toggle(kind)
                        }
                    }
                }
                if permission == .denied && isAnyOn {
                    Text(polish: "powiadomienia są wyłączone w ustawieniach telefonu – przypomnę, gdy je włączysz")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task {
            guard !LaunchArguments.usesDemoData else { return }
            permission = await ReminderPermission.current()
        }
    }

    /// "woda · 11:00, 15:00 i 19:00": what it is and when it comes, in one line.
    private func title(of kind: ReminderKind, in reminders: ReminderSettings) -> String {
        switch kind {
        case .water:
            return "woda · " + WelcomeWords.list(reminders.waterTimes.map(\.text))
        case .weighIn:
            return "ważenie · \(WelcomeWords.weekdayPhrase(reminders.weighInWeekday)) o \(reminders.weighIn.time.text)"
        case .periodSoon:
            return "dwa dni przed okresem · \(reminders.periodSoon.time.text)"
        case .dinner:
            return "kolacja · \(reminders.dinner.time.text)"
        case .letter:
            return "list do siebie · \(reminders.letter.time.text)"
        }
    }

    /// On at once, off at once. Turning the first one on asks iOS (never in the demo); once she
    /// allows notifications, the day a letter to herself opens is on too, like in "ustawienia".
    private func toggle(_ kind: ReminderKind) {
        let wasOn = store.data.settings.reminders[kind].isOn
        guard store.updateSettings({ $0.reminders[kind].isOn = !wasOn }) else { return }
        guard !wasOn, !LaunchArguments.usesDemoData, !isAsking else { return }
        isAsking = true
        Task {
            if await ReminderPermission.current() == .notAsked {
                if await ReminderPermission.ask() {
                    store.updateSettings { $0.reminders.letter.isOn = true }
                }
            }
            permission = await ReminderPermission.current()
            isAsking = false
        }
    }
}

/// "tylko dla Twoich oczu": the Face ID lock. Turning it on asks for Face ID once, so she sees it
/// works; a phone without a passcode can't be locked, and she is told so gently.
struct WelcomeLockStep: View {
    @Environment(AppStore.self) private var store
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var isTurningOn = false
    /// A gentle line when the lock couldn't be turned on.
    @State private var note: String? = nil

    var body: some View {
        let isOn = store.data.settings.isLockEnabled
        WelcomePage(step: .lock,
                    title: "tylko dla Twoich oczu",
                    subtitle: "zanim pokażę Twoje dane, poproszę o Face ID",
                    canSkip: !isOn,
                    onBack: onBack,
                    onNext: onNext) {
            VStack(alignment: .leading, spacing: Spacing.group) {
                ToggleTile(title: "blokada Face ID", isOn: isOn) {
                    toggle(isOn: isOn)
                }
                if let note {
                    Text(polish: note)
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isOn {
                    ConfirmationNote(text: "włączyłam – do środka zajrzysz tylko Ty")
                }
            }
            .animation(.smooth(duration: 0.25), value: isOn)
        }
    }

    /// Off at once; on only after Face ID (or the passcode) confirms it's her – the same way as in
    /// "ustawienia". The demo has no lock, so there the tile only shows how it looks.
    private func toggle(isOn: Bool) {
        note = nil
        guard !isOn else {
            store.setLockEnabled(false)
            return
        }
        guard AppLockSession.isAvailable else {
            store.setLockEnabled(true)
            return
        }
        guard !isTurningOn else { return }
        isTurningOn = true
        Task {
            let result = await AppLockSession.shared.turnOn(store)
            isTurningOn = false
            if case .noPasscode = result {
                note = "ten telefon nie ma kodu, więc blokady nie włączę – wrócisz do niej w ustawieniach"
            }
        }
    }
}

/// Weekdays and lists in Polish for the welcome's lines.
enum WelcomeWords {
    private static let weekdayPhrases = ["w poniedziałek", "we wtorek", "w środę", "w czwartek", "w piątek",
                                         "w sobotę", "w niedzielę"]

    /// "w poniedziałek" for ISO weekday 1; a weekday outside 1–7 is clamped.
    static func weekdayPhrase(_ weekday: Int) -> String {
        weekdayPhrases[Swift.min(Swift.max(weekday, 1), 7) - 1]
    }

    /// "11:00", "13:00 i 17:00", "11:00, 15:00 i 19:00"
    static func list(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        let rest = items.dropLast()
        return rest.isEmpty ? last : rest.joined(separator: ", ") + " i " + last
    }
}
