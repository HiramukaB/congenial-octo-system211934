import Foundation
import AboutHerCore

/// The inner self: intentions, small wins, the manifest, weekly reflections, letters to herself
/// and progress photos.
extension AppStore {
    // MARK: - Intention

    /// Saves her intention for `day` (today or earlier); an empty text removes it.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func setIntention(_ text: String, on day: LocalDate) -> Bool {
        guard day <= today else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return change { $0.setIntention(trimmed, on: day) }
    }

    // MARK: - Small wins

    /// Returns `false` when nothing was saved.
    @discardableResult
    func addWin(_ text: String, on day: LocalDate) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, day <= today else { return false }
        let win = SmallWin(day: day, text: trimmed)
        return change { $0.wins.append(win) }
    }

    /// Corrects a win; an empty text changes nothing – a win is deleted with a swipe.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func updateWin(_ id: UUID, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, data.wins.contains(where: { $0.id == id }) else { return false }
        return change { appData in
            if let index = appData.wins.firstIndex(where: { $0.id == id }) {
                appData.wins[index].text = trimmed
            }
        }
    }

    func removeWin(_ id: UUID) {
        change { appData in
            appData.wins.removeAll { $0.id == id }
        }
    }

    // MARK: - Manifest

    /// "kim się stajesz"; an empty text clears it.
    @discardableResult
    func setManifest(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return change { $0.manifest = trimmed }
    }

    // MARK: - Weekly reflection

    /// Saves her answer to the question of the week `day` falls in; an empty answer removes it.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func setReflection(question: String, answer: String, forWeekOf day: LocalDate) -> Bool {
        guard day <= today else { return false }
        let reflection = WeeklyReflection(question: question,
                                          answer: answer.trimmingCharacters(in: .whitespacesAndNewlines))
        return change { $0.setReflection(reflection, forWeekOf: day) }
    }

    // MARK: - Letters

    /// Seals a letter written today until `opensOn`, which must be after today.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func addLetter(_ text: String, opensOn: LocalDate) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, opensOn > today else { return false }
        let letter = Letter(writtenOn: today, opensOn: opensOn, text: trimmed)
        return change { $0.letters.append(letter) }
    }

    /// Seals the letter `id`, written today, until `opensOn` (after today). One that is in her data
    /// already – saved while she was still writing, when the app went to the background – gets the
    /// new text and opening day. Returns `false` when nothing was saved.
    @discardableResult
    func sealLetter(id: UUID, text: String, opensOn: LocalDate) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, opensOn > today else { return false }
        let writtenOn = today
        return change { appData in
            if let index = appData.letters.firstIndex(where: { $0.id == id }) {
                appData.letters[index].text = trimmed
                appData.letters[index].opensOn = opensOn
            } else {
                appData.letters.append(Letter(id: id, writtenOn: writtenOn, opensOn: opensOn, text: trimmed))
            }
        }
    }

    func removeLetter(_ id: UUID) {
        change { appData in
            appData.letters.removeAll { $0.id == id }
        }
    }

    // MARK: - Checks

    /// Whether her data can be changed right now. When it can't, she is told why, as with any
    /// refused change – so a letter isn't started that couldn't be kept.
    func acceptsChanges() -> Bool {
        change { _ in }
    }

    // MARK: - Photos

    /// Where the JPEG of `photo` is. The file may be missing (e.g. after her data came back from a
    /// daily copy), so show a gentle placeholder then.
    func photoURL(_ photo: ProgressPhoto) -> URL {
        photosDirectory.appending(path: photo.fileName)
    }

    /// Keeps a photo (JPEG data) for `day` in the app's own photos folder, protected while the
    /// phone is locked. The file is written first, so her data never points at a photo that isn't
    /// there. Returns `false` when nothing was saved.
    @discardableResult
    func addPhoto(jpeg: Data, on day: LocalDate) -> Bool {
        guard !jpeg.isEmpty, day <= today else { return false }
        let photo = ProgressPhoto(day: day)
        let url = photoURL(photo)
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            try jpeg.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            problem = "nie udało mi się zapisać zdjęcia. Spróbuj jeszcze raz za chwilę"
            return false
        }
        guard change({ $0.photos.append(photo) }) else {
            // Her data can't be changed right now (the store says why): the file goes too.
            try? FileManager.default.removeItem(at: url)
            return false
        }
        // The photo and her data file go to disk together.
        saveNow()
        return true
    }

    /// Removes a photo from her data and deletes its file.
    func removePhoto(_ id: UUID) {
        guard let photo = data.photos.first(where: { $0.id == id }) else { return }
        let removed = change { appData in
            appData.photos.removeAll { $0.id == id }
        }
        guard removed else { return }
        saveNow()
        try? FileManager.default.removeItem(at: photoURL(photo))
    }
}
