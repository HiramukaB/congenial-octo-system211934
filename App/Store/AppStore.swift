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
    /// Her file hasn't been read yet: it exists but can't be read right now (e.g. the phone hasn't
    /// been unlocked since a restart), or it is missing while daily copies exist, which can be read
    /// only once the app is in use.
    @ObservationIgnored private var unreadPersistence: Persistence?
    /// Why changes can't be made right now, when they can't.
    @ObservationIgnored private var readOnlyReason: String?
    @ObservationIgnored private var hasUnsavedChanges = false
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var parserCache: (foods: [FoodItem], parser: MealParser)?
    /// Where her progress photos are kept: one JPEG per photo in a folder next to her data file,
    /// never inside the data file and never in her photo library. The demo uses a temporary folder,
    /// so it never touches her files.
    let photosDirectory: URL

    init(data: AppData, persistence: Persistence?, photosDirectory: URL, today: LocalDate = .today()) {
        self.data = data
        self.persistence = persistence
        self.photosDirectory = photosDirectory
        self.today = today
    }

    /// The real store, or – with "-demoData" or "-showOnboarding" (`LaunchArguments`) – a fictional
    /// history kept only in memory.
    static func makeDefault() -> AppStore {
        if LaunchArguments.usesDemoData {
            let demoPhotos = FileManager.default.temporaryDirectory
                .appending(path: "AboutHer-demo-photos", directoryHint: .isDirectory)
            var demo = DemoData.make(today: .today())
            if LaunchArguments.showsOnboarding {
                // The welcome on top of data that is already there, as after an update on her phone.
                demo.settings.onboarding.completedAt = nil
                demo.settings.onboarding.hasSeenTutorial = false
            }
            return AppStore(data: demo, persistence: nil, photosDirectory: demoPhotos)
        }
        let live = Persistence.live()
        let store = AppStore(data: AppData(), persistence: nil, photosDirectory: live.photosDirectory)
        store.unreadPersistence = live
        store.openSavedData(isActive: false)
        return store
    }

    var cycle: CycleEngine {
        CycleEngine(periodDays: data.periodDays, today: today)
    }

    /// Her data has been read and can be changed: false while her file is unread and in read-only
    /// mode. Unlike `change`, asking never shows her anything.
    ///
    /// What it reads isn't observed, but it only ever changes together with `data` or `problem`
    /// (or before the first screen is drawn), so views that read it are redrawn in time.
    var isEditable: Bool {
        unreadPersistence == nil && readOnlyReason == nil
    }

    // MARK: - Changes

    /// Makes one change to her data and saves it shortly after, like every change in the app.
    /// Refused (returns `false`) while her file hasn't been read and in read-only mode – she is
    /// told why. A change that changes nothing isn't saved. The features' own extensions
    /// (AppStore+Symptoms, +Settings, +Movement, +Inner, +Moment, +Onboarding, +Humor) make their
    /// changes through it.
    @discardableResult
    func change(_ body: (inout AppData) -> Void) -> Bool {
        guard canEdit() else { return false }
        var updated = data
        body(&updated)
        if updated != data {
            data = updated
            markChanged()
        }
        return true
    }

    func togglePeriodDay(_ date: LocalDate) {
        // Future days can't be marked, but a future day marked earlier can still be removed.
        guard date <= today || data.periodDays.contains(date) else { return }
        guard canEdit() else { return }
        data.togglePeriodDay(date)
        markChanged()
    }

    // MARK: - Food

    /// The meal parser with her own products; rebuilt only when they change.
    var mealParser: MealParser {
        if let cached = parserCache, cached.foods == data.userFoods {
            return cached.parser
        }
        let parser = MealParser(catalog: .builtIn, userFoods: data.userFoods)
        parserCache = (data.userFoods, parser)
        return parser
    }

    /// Logs what she typed for `day`. Returns `false` when nothing was saved.
    @discardableResult
    func logMeal(_ text: String, on day: LocalDate) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, day <= today, canEdit() else { return false }
        data.addMeal(MealEntry(text: trimmed, parsed: mealParser.parse(trimmed)), on: day)
        markChanged()
        return true
    }

    /// Replaces what she wrote for a logged meal and counts it again. The meal keeps its id, its
    /// time and its place in the day. An empty text changes nothing – a meal is deleted with a
    /// swipe. Returns `false` when nothing was saved.
    @discardableResult
    func replaceMeal(_ id: UUID, text: String, on day: LocalDate) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canEdit(), data.meals(on: day).contains(where: { $0.id == id }) else { return false }
        let parsed = mealParser.parse(trimmed)
        data.updateMeal(id: id, on: day, text: trimmed, parsed: parsed)
        markChanged()
        return true
    }

    func removeMeal(_ id: UUID, on day: LocalDate) {
        guard canEdit() else { return }
        data.removeMeal(id: id, on: day)
        markChanged()
    }

    /// Remembers a product she taught the app and counts it in every entry that missed it.
    /// Taught again (same id or name), it replaces the earlier one in every meal that used it.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func teachFood(_ item: FoodItem) -> Bool {
        guard canEdit() else { return false }
        data.teachFood(item, catalog: .builtIn)
        markChanged()
        return true
    }

    /// One of the products she taught the app, as it is stored now.
    func userFood(id: String) -> FoodItem? {
        data.userFoods.first { $0.id == id }
    }

    func addWater(_ delta: Int, to slot: WaterDay.Slot, on day: LocalDate) {
        guard day <= today, canEdit() else { return }
        data.addWater(delta, to: slot, on: day)
        markChanged()
    }

    /// Saves a weigh-in rounded to 0.1 kg. Values outside 25–250 kg are refused (returns `false`).
    @discardableResult
    func setWeight(_ kg: Double, on day: LocalDate) -> Bool {
        guard (25...250).contains(kg), day <= today, canEdit() else { return false }
        data.setWeight((kg * 10).rounded() / 10, on: day)
        markChanged()
        return true
    }

    func removeWeight(on day: LocalDate) {
        guard canEdit() else { return }
        data.setWeight(nil, on: day)
        markChanged()
    }

    /// Saves how her daily targets are set. A `nil` profile keeps the stored one, so her own
    /// targets can be saved without giving any personal data – unless `clearsProfile` says she
    /// emptied every field about herself; then the stored one goes too. Returns `false` when
    /// nothing was saved.
    @discardableResult
    func saveNutrition(profile: NutritionProfile?, targets: TargetsSetting, clearsProfile: Bool = false) -> Bool {
        guard canEdit() else { return false }
        if let profile {
            data.nutritionProfile = profile
        } else if clearsProfile {
            data.nutritionProfile = nil
        }
        data.targetsSetting = targets
        markChanged()
        return true
    }

    /// Her weigh-ins with the smoothed trend line.
    var weightPoints: [WeightPoint] {
        WeightTrend.points(data.weights)
    }

    /// The weight targets are computed from: the trend of her weigh-ins, otherwise the profile weight.
    var currentWeight: Double? {
        WeightTrend.trend(on: today, in: weightPoints) ?? data.nutritionProfile?.weightKg
    }

    /// Targets computed from her profile; `nil` until she fills it in.
    var computedTargets: TargetResult? {
        guard let profile = data.nutritionProfile else { return nil }
        return TargetCalculator.compute(profile: profile, weightKg: currentWeight, year: today.year)
    }

    /// The daily targets in use: her own numbers, or computed from the profile.
    var targets: Macros? {
        switch data.targetsSetting {
        case .manual(let macros): macros
        case .automatic: computedTargets?.targets
        }
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

        guard let raw else {
            // No file. Without daily copies this is simply the first launch. With copies, the file is
            // gone – and before the phone has been unlocked even the copies can't be read, so that
            // case is decided only once the app is in use.
            if candidate.hasBackupFiles && !isActive { return }
            unreadPersistence = nil
            persistence = candidate
            if restoreNewestBackup(from: candidate, because: "nie znalazłam pliku z Twoimi danymi") {
                return
            }
            if candidate.hasBackupFiles {
                problem = "nie znalazłam pliku z Twoimi danymi, a zapisanych kopii nie udało mi się odczytać, więc zaczynam od pustego kalendarza"
            }
            return
        }
        unreadPersistence = nil

        if AppDataCoding.isFromNewerVersion(raw) {
            readOnlyReason = "te dane zapisała nowsza wersja aplikacji. Zainstaluj ją, żeby wprowadzać zmiany"
            if let newer = try? AppDataCoding.decode(raw) {
                data = newer
                problem = "te dane zapisała nowsza wersja aplikacji. Pokażę je, ale niczego nie zapiszę, żeby nic nie zginęło. Zainstaluj najnowszą wersję"
            } else {
                // Something deep inside only a newer version knows: nothing can be shown, and
                // nothing is written, so it all comes back once she installs that version.
                problem = "te dane zapisała nowsza wersja aplikacji, a ja nie umiem ich jeszcze pokazać. Niczego nie zapiszę, żeby nic nie zginęło. Zainstaluj najnowszą wersję"
            }
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
            persistence = candidate
            if !restoreNewestBackup(from: candidate,
                                    because: "nie udało mi się odczytać zapisanych danych",
                                    footnote: ". Uszkodzony plik zachowałam") {
                problem = "nie udało mi się odczytać zapisanych danych, a nie mam żadnej dobrej kopii, więc zaczynam od pustego kalendarza. Uszkodzony plik zachowałam, da się go jeszcze odzyskać"
            }
        }
    }

    /// Loads the newest readable daily copy and saves it as her file right away.
    /// Returns `false` when there is no copy to restore.
    private func restoreNewestBackup(from candidate: Persistence, because reason: String, footnote: String = "") -> Bool {
        guard let backup = candidate.newestReadableBackup() else { return false }
        data = backup.data
        hasUnsavedChanges = true
        let saved = write()
        let restored = "\(reason), więc wczytałam kopię z \(PolishDate.dayMonth(backup.day)). Sprawdź ostatnie dni w kalendarzu\(footnote)"
        problem = saved
            ? restored
            : restored + ". Nie udało mi się jeszcze zapisać wczytanej kopii – spróbuję znowu przy kolejnej zmianie albo gdy wyjdziesz z aplikacji"
        return true
    }

    /// Changes are refused while her file hasn't been read and in read-only mode.
    private func canEdit() -> Bool {
        if unreadPersistence != nil {
            // She is using the app, so the phone is unlocked: try reading her file once more.
            openSavedData(isActive: true)
        }
        if unreadPersistence != nil {
            if problem == nil {
                problem = "jeszcze nie wczytałam Twoich danych, więc niczego teraz nie zmienię. Zamknij aplikację i otwórz ją jeszcze raz"
            }
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

    /// Saves pending changes. Returns `false` only when saving failed.
    @discardableResult
    private func write() -> Bool {
        guard hasUnsavedChanges, let persistence else { return true }
        do {
            try persistence.save(data)
            hasUnsavedChanges = false
            return true
        } catch {
            problem = "nie udało mi się zapisać ostatnich zmian. Spróbuję jeszcze raz przy kolejnej zmianie albo gdy wyjdziesz z aplikacji. Szczegóły: \(error.localizedDescription)"
            return false
        }
    }
}
