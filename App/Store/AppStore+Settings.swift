import Foundation
import AboutHerCore

/// Her settings: reminders and the lock.
extension AppStore {
    /// Changes her settings, e.g. `updateSettings { $0.reminders.water.isOn = true }`.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func updateSettings(_ body: (inout AppSettings) -> Void) -> Bool {
        change { appData in
            body(&appData.settings)
        }
    }

    /// Turns the Face ID lock on or off.
    @discardableResult
    func setLockEnabled(_ isOn: Bool) -> Bool {
        updateSettings { $0.isLockEnabled = isOn }
    }
}
