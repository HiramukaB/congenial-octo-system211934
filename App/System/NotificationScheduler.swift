import Foundation
import UserNotifications
import AboutHerCore

/// Her local reminders: water, the weekly weigh-in, a discreet note two days before the expected
/// period, "dopisać kolację?" in the evening and the day a letter to herself opens.
///
/// RootView calls `refresh` when the app becomes active and whenever `inputs` change. A refresh
/// waits out a burst of changes, then replaces this app's pending notifications with the week
/// `ReminderPlan` works out. It never asks for permission itself – SettingsView asks when she
/// turns her first reminder on – and the demo never touches the phone's notifications.
enum NotificationScheduler {
    private static let isDemo = LaunchArguments.usesDemoData
    /// The refresh that is waiting or running; a newer one waits for it to finish.
    private static var pendingRefresh: Task<Void, Never>?
    /// Something was scheduled since the app started.
    private static var hasScheduled = false

    /// Everything the scheduled reminders depend on.
    static func inputs(_ store: AppStore) -> ReminderInputs {
        ReminderInputs(facts: ReminderPlan.Facts(data: store.data, today: store.today, calendar: .current))
    }

    /// Schedules her reminders as her settings say, and removes the ones she turned off.
    static func refresh(_ store: AppStore) {
        guard !isDemo else { return }
        let previous = pendingRefresh
        previous?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(for: .milliseconds(500))
            // Two refreshes never mix their requests: the earlier one finishes first.
            if let previous {
                await previous.value
            }
            guard !Task.isCancelled else { return }
            await apply(store)
        }
    }

    private static func apply(_ store: AppStore) async {
        guard store.data.settings.reminders.isAnyOn else {
            // All off: nothing stays planned. While her file may still be unread, the data is
            // empty – then what was planned before stays, unless it was planned in this run.
            if hasScheduled || store.data != AppData() {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                hasScheduled = false
            }
            return
        }
        let permission = await ReminderPermission.current()
        // Read after the wait, so the newest data counts.
        let planned = permission == .allowed
            ? ReminderPlan.reminders(for: store.data, now: Date(), calendar: .current)
            : []
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for reminder in planned {
            center.add(request(for: reminder), withCompletionHandler: nil)
        }
        hasScheduled = !planned.isEmpty
    }

    private static func request(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        // Grouped by kind in Notification Centre.
        content.threadIdentifier = ReminderPlan.identifierPrefix + reminder.kind.rawValue
        // Her wall-clock time, so it still comes at 11:00 after a time zone change.
        var moment = DateComponents()
        moment.year = reminder.day.year
        moment.month = reminder.day.month
        moment.day = reminder.day.day
        moment.hour = reminder.time.hour
        moment.minute = reminder.time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }
}

/// What the reminders depend on; RootView refreshes them when it changes.
nonisolated struct ReminderInputs: Equatable {
    var facts: ReminderPlan.Facts
}

/// Whether iOS lets her reminders through.
nonisolated enum ReminderPermission: Sendable {
    case notAsked, allowed, denied

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notAsked
        case .denied: self = .denied
        case .authorized, .provisional, .ephemeral: self = .allowed
        @unknown default: self = .allowed
        }
    }

    /// The answer iOS has now.
    static func current() async -> ReminderPermission {
        await withCheckedContinuation { (continuation: CheckedContinuation<ReminderPermission, Never>) in
            UNUserNotificationCenter.current().getNotificationSettings { @Sendable settings in
                continuation.resume(returning: ReminderPermission(settings.authorizationStatus))
            }
        }
    }

    /// Asks her whether the app may send reminders; iOS shows the question only the first time.
    /// True when she allowed them.
    static func ask() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { @Sendable granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }
}
