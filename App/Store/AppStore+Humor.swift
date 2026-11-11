import Foundation
import AboutHerCore

/// "humor": jokes and quotes she keeps to cheer herself up. Drawing one at random and when "dziś"
/// offers one live in AboutHerCore (`AppData.randomHumor`, `HumorNudge`).
extension AppStore {
    /// Adds a joke or a quote. An empty text adds nothing. Returns `false` when nothing was saved.
    @discardableResult
    func addHumor(_ text: String, kind: HumorItem.Kind, source: String? = nil) -> Bool {
        saveHumor(HumorItem(text: text, kind: kind, source: source))
    }

    /// Adds `item`, or – when one with its id is already there – corrects it in its place; it keeps
    /// the time it was added. The text is trimmed; an empty one changes nothing (one is deleted with
    /// a swipe). Returns `false` when nothing was saved.
    ///
    /// A field that saves itself on closing can make the item (and its id) when it opens and save
    /// it under that id each time, like a letter in "list do siebie".
    @discardableResult
    func saveHumor(_ item: HumorItem) -> Bool {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var cleaned = item
        cleaned.text = trimmed
        cleaned.source = HumorItem.cleanSource(item.source)
        return change { $0.saveHumor(cleaned) }
    }

    /// Corrects a joke or a quote; an empty text changes nothing. Returns `false` when nothing was saved.
    @discardableResult
    func updateHumor(_ id: UUID, text: String, kind: HumorItem.Kind, source: String?) -> Bool {
        guard var item = data.humor.first(where: { $0.id == id }) else { return false }
        item.text = text
        item.kind = kind
        item.source = source
        return saveHumor(item)
    }

    /// Marks it as a favourite, or takes the mark back. Returns `false` when nothing was saved.
    @discardableResult
    func setHumorFavorite(_ id: UUID, _ isFavorite: Bool) -> Bool {
        change { $0.setHumorFavorite(id: id, isFavorite) }
    }

    /// Turns the favourite mark of a joke or a quote on or off, from what is saved now.
    /// Returns `false` when nothing was saved.
    @discardableResult
    func toggleHumorFavorite(_ id: UUID) -> Bool {
        guard let item = data.humor.first(where: { $0.id == id }) else { return false }
        return setHumorFavorite(id, !item.isFavorite)
    }

    func removeHumor(_ id: UUID) {
        change { $0.removeHumor(id: id) }
    }

    /// Whether her collection can be changed right now. When it can't, she is told why, as with
    /// any refused change – so a field doesn't open for words that couldn't be kept.
    func acceptsHumorChanges() -> Bool {
        change { _ in }
    }
}
