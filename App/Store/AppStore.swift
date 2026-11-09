import Foundation
import Observation
import AboutHerCore

/// The single source of truth. Everything she logs lives in `data` and is written
/// to one JSON file shortly after each change (and right away when the app goes to the background).
@Observable
final class AppStore {
    private(set) var data: AppData
    private(set) var today: LocalDate
    /// Shown once as an alert when loading or saving fails, so a problem never goes unnoticed.
    var problem: String?

    private let persistence: Persistence?
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
        let persistence = Persistence.live()
        do {
            let saved = try persistence.load() ?? AppData()
            persistence.makeDailyBackup(today: .today())
            return AppStore(data: saved, persistence: persistence)
        } catch {
            persistence.setAsideDamagedFile()
            let store = AppStore(data: AppData(), persistence: persistence)
            store.problem = "Nie udało mi się odczytać zapisanych danych. Uszkodzony plik odłożyłam na bok i niczego nie nadpisałam."
            return store
        }
    }

    var cycle: CycleEngine {
        CycleEngine(periodDays: data.periodDays)
    }

    // MARK: - Changes

    func togglePeriodDay(_ date: LocalDate) {
        guard date <= today else { return }
        data.togglePeriodDay(date)
        scheduleSave()
    }

    /// Adds period days from an old backup and returns how many of them were new.
    @discardableResult
    func importPeriodDays(_ days: Set<LocalDate>) -> Int {
        let added = days.subtracting(data.periodDays).count
        guard added > 0 else { return 0 }
        data.periodDays.formUnion(days)
        scheduleSave()
        return added
    }

    func refreshToday() {
        let now = LocalDate.today()
        if now != today {
            today = now
        }
    }

    // MARK: - Saving

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        write()
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
        guard let persistence else { return }
        do {
            try persistence.save(data)
        } catch {
            problem = "Nie udało mi się zapisać ostatniej zmiany (\(error.localizedDescription))."
        }
    }
}
