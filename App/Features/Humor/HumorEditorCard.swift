import SwiftUI
import AboutHerCore

/// A joke or a quote being written or corrected, in place: what it is ("żart", "cytat", "inne"),
/// her words and, if she wants, who said it. It saves itself – when the keyboard goes, when she
/// leaves the screen and when the app goes to the background – so there is no save button. The
/// return key goes from her words to the author, and from there it closes the card.
struct HumorEditorCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The id it is saved under. A new one's is made when the card opens, so every save (in the
    /// background, then on closing) lands on the same item.
    let itemID: UUID
    /// A new one, not yet in her collection when the card opened.
    let isNew: Bool
    /// Called once, when the card closes: `true` when something was saved.
    let onClose: (Bool) -> Void

    @State private var text: String
    @State private var source: String
    @State private var kind: HumorItem.Kind
    @State private var isClosed = false
    @FocusState private var focus: HumorEditorField?

    /// `original` is the item she tapped to correct, nil for a new one.
    init(itemID: UUID, original: HumorItem?, onClose: @escaping (Bool) -> Void) {
        self.itemID = itemID
        self.isNew = original == nil
        self.onClose = onClose
        _text = State(initialValue: original?.text ?? "")
        _source = State(initialValue: original?.source ?? "")
        _kind = State(initialValue: original?.kind ?? .joke)
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.item) {
                ChoiceTiles(options: HumorItem.Kind.allCases,
                            selection: kind,
                            columns: dynamicTypeSize.isAccessibilitySize ? 1 : 3,
                            label: { $0.label },
                            onSelect: { kind = $0 })
                TextField("wpisz albo wklej coś zabawnego", text: $text, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(Palette.text)
                    .lineLimit(2...10)
                    .focused($focus, equals: .text)
                    .submitLabel(.next)
                    .onSubmit {
                        focus = .source
                    }
                    .onAppear {
                        focus = .text
                    }
                    .fieldBox()
                TextField("autor albo źródło – jeśli chcesz", text: $source)
                    .font(.body)
                    .foregroundStyle(Palette.text)
                    .focused($focus, equals: .source)
                    .submitLabel(.done)
                    .onSubmit {
                        focus = nil
                    }
                    .fieldBox()
                Text(polish: hint)
                    .hintText()
            }
        }
        .onChange(of: text) { oldValue, newValue in
            // The return key in her words goes on to the author; a pasted text keeps its lines.
            if let typed = Self.textOnReturnKey(old: oldValue, new: newValue) {
                text = typed
                focus = .source
            }
        }
        .onChange(of: focus) { _, newFocus in
            if newFocus == nil {
                closeSoon()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: keep what is there now.
            if phase == .background {
                _ = save()
                store.saveNow()
            }
        }
        .onDisappear {
            // She left the screen, or opened another one, before the keyboard went.
            finish()
        }
    }

    private var hint: String {
        if !isNew && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "pusty tekst niczego nie zmieni – usuniesz go, przesuwając w lewo"
        }
        return "zapiszę, gdy schowasz klawiaturę"
    }

    /// The keyboard went away (the return key, a drag down): she is done. A short wait first, in
    /// case she only went from one field to the other.
    private func closeSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if focus == nil {
                finish()
            }
        }
    }

    /// Saves and closes the card, once. While her data can't be changed (the store tells her why),
    /// her words stay in the card.
    private func finish() {
        guard !isClosed else { return }
        switch save() {
        case .refused:
            return
        case .saved:
            isClosed = true
            onClose(true)
        case .unchanged:
            isClosed = true
            onClose(false)
        }
    }

    /// Saves the fields under `itemID`, keeping when it was added and whether it is a favourite.
    private func save() -> HumorSaveResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = store.data.humor.first(where: { $0.id == itemID })
        guard !trimmed.isEmpty else {
            // A new one emptied after it was saved in the background goes again; one she corrects
            // stays as it was (it is deleted with a swipe).
            if isNew && stored != nil {
                store.removeHumor(itemID)
            }
            return .unchanged
        }
        let item = HumorItem(id: itemID, text: trimmed, kind: kind, source: source,
                             createdAt: stored?.createdAt ?? Date(), isFavorite: stored?.isFavorite ?? false)
        if item == stored {
            return .unchanged
        }
        return store.saveHumor(item) ? .saved : .refused
    }

    /// The return key of a multi-line field adds a line break; here it means "dalej". It is the
    /// change that adds one line break and nothing else – or, with an autocorrection, ends the
    /// text with it. Returns the text without that line break, or nil for any other change.
    private static func textOnReturnKey(old: String, new: String) -> String? {
        let addedBreaks = new.filter(\.isNewline).count - old.filter(\.isNewline).count
        guard addedBreaks == 1 else { return nil }
        if new.filter({ !$0.isNewline }) == old.filter({ !$0.isNewline }) {
            return old
        }
        if new.last?.isNewline == true && new.count - old.count <= 2 {
            return String(new.dropLast())
        }
        return nil
    }
}

/// The two fields of the editor.
nonisolated enum HumorEditorField: Hashable {
    case text
    case source
}

/// What saving the editor did.
private nonisolated enum HumorSaveResult {
    case saved
    case unchanged
    /// Her data can't be changed right now.
    case refused
}
