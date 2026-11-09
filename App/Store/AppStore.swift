import Foundation
import Observation
import AboutHerCore

/// The single source of truth. Everything she logs lives in `data` and is written
/// to one JSON file shortly after each change (and right away when the app goes to the background).
///
/// Her history is never overwritten by something the app failed to read: nothing is saved
/// until the file has been read, files from a newer version are only shown, and a damaged
/// file is put aside before anything else is written.
@Observable
final class AppStore {
    private(set) var data: AppData
    private(set) var today: LocalDate
    /// Shown once as an alert when loading or saving fails, so a problem never goes unnoticed.
    var problem: String?

    /// Where changes are saved: `nil` until her file has been read, in read-only mode and in the demo.
    @ObservationIgnored private var persistence: Persistence?
    /// Her file exists but couldn't be read yet (e.g. the phone hasn't been unlocked since a restart).
    @ObservationIgnored private var unreadPersistence: Persistence?
    /// Why changes can't be made right now, when they can't.
    @ObservationIgnored private var readOnlyReason: String?
    @ObservationIgnored private var hasUnsavedChanges = false
    @ObservationIgnored private var pendingSave: Task<Void, Never>?

    init(data: AppData, persistence: Persistence?, today: LocalDate = .today()) {
        self.data = data
        self.persistence = persistence
        self.today = today
    }

    /// The real store, or – with the "-demoData" launch argument – a fictional history kept only in memory.
    static func makeDefault() -> AppStore {
        if ProcessInfo.processInfo.arguments.contains("-demoData") {
            return AppStore(data: DemoData.make(today: .today()), persistence: nil)
        }
        let store = AppStore(data: AppData(), persistence: nil)
        store.unreadPersistence = Persistence.live()
        store.openSavedData(isActive: false)
        return store
    }

    var cycle: CycleEngine {
        CycleEngine(periodDays: data.periodDays, today: today)
    }

    // MARK: - Changes

    func togglePeriodDay(_ date: LocalDate) {
        // Future days can't be marked, but a future day marked earlier can still be removed.
        guard date <= today || data.periodDays.contains(date) else { return }
        guard canEdit() else { return }
        data.togglePeriodDay(date)
        markChanged()
    }

    /// Adds period days from an old backup and returns how many of them were new,
    /// or `nil` when nothing can be changed right now. Future days are skipped.
    func importPeriodDays(_ days: Set<LocalDate>) -> Int? {
        guard canEdit() else { return nil }
        let pastDays = days.filter { $0 <= today }
        let added = pastDays.subtracting(data.periodDays).count
        guard added > 0 else { return 0 }
        data.periodDays.formUnion(pastDays)
        markChanged()
        return added
    }

    /// Called whenever the app becomes active and at midnight.
    func refreshToday() {
        openSavedData(isActive: true)
        let now = LocalDate.today()
        if now != today {
            today = now
            persistence?.makeDailyBackup(today: now)
        }
    }

    // MARK: - Loading

    /// Reads her saved file. Until that has worked nothing is ever written, so a file that is
    /// only locked for now can't be overwritten with an empty calendar.
    private func openSavedData(isActive: Bool) {
        guard let candidate = unreadPersistence else { return }
        let raw: Data?
        do {
            raw = try candidate.readSavedFile()
        } catch {
            // Locked or temporarily unavailable: change nothing and try again on the next activation.
            if isActive {
                problem = "nie mogę teraz otworzyć Twoich danych. Niczego nie zmieniłam – zamknij aplikację i otwórz ją jeszcze raz"
            }
            return
        }
        unreadPersistence = nil

        guard let raw else {
            // The very first launch – or the main file is gone, and then the newest copy is the best start.
            if let backup = candidate.newestReadableBackup() {
                data = backup.data
                hasUnsavedChanges = true
                problem = "nie znalazłam pliku z Twoimi danymi, więc wczytałam kopię z \(PolishDate.dayMonth(backup.day)). Sprawdź ostatnie dni w kalendarzu"
            }
            persistence = candidate
            return
        }

        if AppDataCoding.isFromNewerVersion(raw) {
            data = (try? AppDataCoding.decode(raw)) ?? AppData()
            readOnlyReason = "te dane zapisała nowsza wersja aplikacji. Zainstaluj ją, żeby wprowadzać zmiany"
            problem = "te dane zapisała nowsza wersja aplikacji. Pokażę je, ale niczego nie zapiszę, żeby nic nie zginęło. Zainstaluj najnowszą wersję"
            return
        }

        do {
            data = try AppDataCoding.decode(raw)
            persistence = candidate
            candidate.makeDailyBackup(today: today)
        } catch {
            guard candidate.setAsideDamagedFile() else {
                readOnlyReason = "nie mogę teraz zapisywać zmian. Zamknij aplikację i otwórz ją jeszcze raz"
                problem = "nie udało mi się odczytać zapisanych danych ani odłożyć ich na bok, więc niczego nie zapisuję. Zamknij aplikację i otwórz ją jeszcze raz"
                return
            }
            if let backup = candidate.newestReadableBackup() {
                data = backup.data
                hasUnsavedChanges = true
                problem = "nie udało mi się odczytać zapisanych danych, więc wczytałam kopię z \(PolishDate.dayMonth(backup.day)). Sprawdź ostatnie dni w kalendarzu. Uszkodzony plik zachowałam"
            } else {
                problem = "nie udało mi się odczytać zapisanych danych, a nie mam żadnej kopii, więc zaczynam od pustego kalendarza. Uszkodzony plik zachowałam, da się go jeszcze odzyskać"
            }
            persistence = candidate
        }
    }

    /// Changes are refused while her file hasn't been read and in read-only mode.
    private func canEdit() -> Bool {
        if unreadPersistence != nil {
            problem = "jeszcze nie wczytałam Twoich danych, więc niczego teraz nie zmienię. Zamknij aplikację i otwórz ją jeszcze raz"
            return false
        }
        if let readOnlyReason {
            problem = readOnlyReason
            return false
        }
        return true
    }

    // MARK: - Saving

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        write()
    }

    private func markChanged() {
        hasUnsavedChanges = true
        scheduleSave()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private func write() {
        guard hasUnsavedChanges, let persistence else { return }
        do {
            try persistence.save(data)
            hasUnsavedChanges = false
        } catch {
            problem = "nie udało mi się zapisać ostatnich zmian. Spróbuję jeszcze raz przy kolejnej zmianie albo gdy wyjdziesz z aplikacji. Szczegóły: \(error.localizedDescription)"
        }
    }
}
