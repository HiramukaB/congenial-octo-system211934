import SwiftUI
import AboutHerCore

/// The field for one note in "chwila dla siebie". It saves itself – when the keyboard goes, when
/// she leaves the screen and when the app goes to the background – so there is no save button.
/// The return key means "gotowe"; a pasted text keeps its lines.
struct MomentNoteField: View {
    /// What the field writes.
    enum Target {
        /// A new note, with the question it answers as she saw it ("" when the words are all hers).
        case new(kind: MomentNote.Kind, prompt: String)
        /// A note she tapped to correct, with its text as it was.
        case existing(id: UUID, originalText: String)
    }

    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let target: Target
    let placeholder: String
    let hint: String
    /// Called once, when her words are saved (`true`) or there was nothing to save (`false`);
    /// the field then goes. While her data can't be written, it stays open with her words.
    let onClose: (Bool) -> Void

    @State private var draft: String
    @State private var isClosed = false
    @FocusState private var isFocused: Bool

    init(target: Target, placeholder: String, hint: String, onClose: @escaping (Bool) -> Void) {
        self.target = target
        self.placeholder = placeholder
        self.hint = hint
        self.onClose = onClose
        switch target {
        case .new:
            _draft = State(initialValue: "")
        case .existing(_, let originalText):
            _draft = State(initialValue: originalText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            TextField(placeholder, text: $draft, axis: .vertical)
                .font(.body)
                .foregroundStyle(Palette.text)
                .focused($isFocused)
                .submitLabel(.done)
                .lineLimit(1...8)
                .onAppear {
                    isFocused = true
                }
            Text(polish: currentHint)
                .hintText()
        }
        .fieldBox()
        .onChange(of: draft) { oldValue, newValue in
            // One line break typed is the return key: it isn't kept, and the field closes.
            if newValue.count == oldValue.count + 1,
               newValue.filter(\.isNewline).count > oldValue.filter(\.isNewline).count {
                draft = oldValue
                isFocused = false
            }
        }
        .onChange(of: isFocused) { _, focused in
            // The keyboard went away (the return key, a drag down, another field): she is done.
            if !focused {
                finish()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: save the field and the file now.
            if phase == .background {
                finish()
                store.saveNow()
            }
        }
        .onDisappear {
            // She left the screen, or another note took this one's place, before the keyboard went.
            finish()
        }
    }

    private var currentHint: String {
        if case .existing = target, draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "pusty tekst niczego nie zmieni – zapisek usuniesz, przesuwając go w lewo"
        }
        return hint
    }

    /// Saves and closes the field, once. If her data can't be written right now (the store says
    /// why), her words stay in the field.
    private func finish() {
        guard !isClosed else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty field changes nothing; a note is deleted with a swipe.
        guard !trimmed.isEmpty else {
            close(saved: false)
            return
        }
        switch target {
        case .new(let kind, let prompt):
            if store.addMomentNote(kind, prompt: prompt, text: trimmed) {
                close(saved: true)
            }
        case .existing(let id, let originalText):
            guard trimmed != originalText, store.data.moments.contains(where: { $0.id == id }) else {
                close(saved: false)
                return
            }
            if store.updateMomentNote(id, text: trimmed) {
                close(saved: true)
            }
        }
    }

    private func close(saved: Bool) {
        isClosed = true
        isFocused = false
        onClose(saved)
    }
}
