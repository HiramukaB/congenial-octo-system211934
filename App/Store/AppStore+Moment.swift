import Foundation
import AboutHerCore

/// "chwila dla siebie": her answers to question cards and her intentions for a meditation.
extension AppStore {
    /// Saves something she wrote today. Returns `false` when nothing was saved.
    @discardableResult
    func addMomentNote(_ kind: MomentNote.Kind, prompt: String, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let note = MomentNote(day: today, kind: kind, prompt: prompt, text: trimmed)
        return change { $0.moments.append(note) }
    }

    /// Corrects what she wrote; an empty text changes nothing – a note is deleted with a swipe.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func updateMomentNote(_ id: UUID, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, data.moments.contains(where: { $0.id == id }) else { return false }
        return change { appData in
            if let index = appData.moments.firstIndex(where: { $0.id == id }) {
                appData.moments[index].text = trimmed
            }
        }
    }

    func removeMomentNote(_ id: UUID) {
        change { appData in
            appData.moments.removeAll { $0.id == id }
        }
    }
}
