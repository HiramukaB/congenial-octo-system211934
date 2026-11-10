import SwiftUI
import AboutHerCore

/// A text she writes in place – an intention, a small win, the manifest, an answer. A tap opens the
/// field and it saves itself: on the return key, when the keyboard goes, when the day or week it
/// belongs to changes, when she leaves the screen and when the app goes to the background. A swipe
/// to the left removes the text, when `delete` is given.
///
/// `key` is what the text belongs to (a day, a week, a win). The open field always saves to the key
/// it was opened for, so nothing lands on a day she didn't mean.
struct InnerTextField<Key: Hashable>: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    let key: Key
    /// The saved text; empty when there is none.
    let text: String
    let placeholder: String
    /// Shown with a star while there is no text; a tap opens the field.
    var emptyLine = ""
    /// Serif italic, for her own sentences (the intention, the manifest).
    var serif = false
    var lines: ClosedRange<Int> = 1...4
    /// A small line under the saved text, e.g. its day.
    var detail: String? = nil
    var deleteLabel = "usuń"
    /// Shown under the field while it is empty, when emptying it doesn't remove the text.
    var emptiedHint: String? = nil
    /// Saves the trimmed text for a key. Returns `false` when the store refused it: the field then
    /// stays open with her words.
    let save: (String, Key) -> Bool
    /// Removes the text of a key (the swipe to the left).
    var delete: ((Key) -> Void)? = nil

    /// The key the open field saves to; nil while it is closed.
    @State private var editingKey: Key? = nil
    /// The text when the field opened: an unchanged one isn't saved again.
    @State private var originalText = ""
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        // A real container, not a Group: a Group would hand onDisappear to the row it replaces
        // when the field opens.
        VStack(alignment: .leading, spacing: 0) {
            if editingKey != nil {
                field
            } else if text.isEmpty {
                emptyRow
            } else {
                savedText
            }
        }
        .onChange(of: isFocused) { _, focused in
            // The keyboard went away (dragged down, another field, another tab): she is done.
            if !focused {
                finish()
            }
        }
        .onChange(of: key) {
            // Another day or week is shown: what she typed goes to the one it was typed for.
            finish(force: true)
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: save the field and the file now.
            if phase == .background && editingKey != nil {
                finish()
                store.saveNow()
            }
        }
        .onDisappear {
            // Another tab or screen took over before the field lost the keyboard.
            finish(force: true)
        }
    }

    // MARK: - Parts

    private var field: some View {
        let isEmpty = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 6) {
            styled(TextField(placeholder, text: $draft, axis: .vertical))
                .foregroundStyle(Palette.text)
                .focused($isFocused)
                .submitLabel(.done)
                .lineLimit(lines)
                .onAppear {
                    // Asked for once more when the field is really there, in case the first
                    // request came too early.
                    isFocused = true
                }
            Text(polish: (isEmpty ? emptiedHint : nil) ?? "zapiszę to, gdy schowasz klawiaturę")
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.accentBackground.opacity(0.6))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1)
        }
        .onChange(of: draft) { oldValue, newValue in
            if let finished = Self.textOnReturnKey(old: oldValue, new: newValue) {
                draft = finished
                finish(typed: finished)
            }
        }
    }

    private var emptyRow: some View {
        Button(action: open) {
            HStack(spacing: 10) {
                OrganicStar()
                    .fill(Palette.accentDim)
                    .frame(width: 11, height: 11)
                    .accessibilityHidden(true)
                Text(polish: emptyLine)
                    .bodyText()
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var savedText: some View {
        let shown = VStack(alignment: .leading, spacing: 3) {
            styled(Text(text))
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Tap to correct it, swipe left to remove it.
        if let delete {
            shown.swipeToDelete(label: deleteLabel, onTap: open) {
                delete(key)
            }
        } else {
            shown
                .contentShape(Rectangle())
                .onTapGesture(perform: open)
        }
    }

    @ViewBuilder
    private func styled(_ content: some View) -> some View {
        if serif {
            content.displayFont(18, italic: true, relativeTo: .body)
        } else {
            content.font(.subheadline)
        }
    }

    // MARK: - Editing

    private func open() {
        originalText = text
        draft = text
        editingKey = key
        isFocused = true
    }

    /// Saves the open field – or `typed`, the text it is about to hold – and closes it. When the
    /// store refuses, her words stay in the field, unless the field has to close (another day,
    /// another screen).
    private func finish(typed: String? = nil, force: Bool = false) {
        guard let target = editingKey else { return }
        let trimmed = (typed ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == originalText || save(trimmed, target) || force {
            editingKey = nil
            draft = ""
        }
        isFocused = false
    }

    /// The return key of a multi-line field inserts a line break; here it means "gotowe". It is the
    /// change that adds one line break and nothing else – or, with an autocorrection, ends the text
    /// with it. Returns the text without that line break, or nil for any other change: a pasted
    /// text keeps its line breaks.
    static func textOnReturnKey(old: String, new: String) -> String? {
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

/// Days as the inner screens name them.
enum InnerFormat {
    /// "dziś", "wczoraj", otherwise the date as in `date`.
    static func day(_ day: LocalDate, today: LocalDate) -> String {
        if day == today {
            return "dziś"
        }
        if day == today.adding(days: -1) {
            return "wczoraj"
        }
        return date(day, today: today)
    }

    /// "7 listopada", with the year when it isn't this year: "7 listopada 2025".
    static func date(_ day: LocalDate, today: LocalDate) -> String {
        day.year == today.year ? PolishDate.dayMonth(day) : "\(PolishDate.dayMonth(day)) \(day.year)"
    }
}
