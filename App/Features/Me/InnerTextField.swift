import SwiftUI
import AboutHerCore

/// How an `InnerTextField` looks while it holds no text yet.
nonisolated enum InnerEmptyStyle: Sendable {
    /// A soft dashed box with a star and the invitation, right where her text will be (an
    /// intention, the manifest, an answer). A tap opens the field in the same place.
    case invitation
    /// A labelled star button, for adding one more (a small win).
    case action
}

/// A text she writes in place – an intention, a small win, the manifest, an answer. A tap opens the
/// field and it saves itself: on the return key, when the keyboard goes, when the day or week it
/// belongs to changes, when she leaves the screen and when the app goes to the background. A swipe
/// to the left removes the text, when `delete` is given. After a save a soft "zapisałam" shows for
/// a moment.
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
    /// Shown while there is no text; a tap opens the field.
    var emptyLine = ""
    /// Serif italic, for her own sentences (the intention, the manifest).
    var serif = false
    var lines: ClosedRange<Int> = 1...4
    /// A small line under the saved text, e.g. its day.
    var detail: String? = nil
    var deleteLabel = "usuń"
    /// Shown under the field while it is empty, when emptying it doesn't remove the text.
    var emptiedHint: String? = nil
    /// How the field looks while there is no text.
    var emptyStyle: InnerEmptyStyle = .invitation
    /// Said softly for a moment after a save; nil for nothing.
    var confirmation: String? = "zapisałam"
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
    /// Counts her saves here; the "zapisałam" of each one fades a moment later.
    @State private var saves = 0
    @State private var showsConfirmation = false
    @FocusState private var isFocused: Bool

    var body: some View {
        // A real container, not a Group: a Group would hand onDisappear to the row it replaces
        // when the field opens.
        VStack(alignment: .leading, spacing: Spacing.tight) {
            if editingKey != nil {
                field
            } else if text.isEmpty {
                emptyState
            } else {
                savedText
            }
            if showsConfirmation, editingKey == nil, let confirmation {
                ConfirmationNote(text: confirmation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .task(id: saves) {
            guard saves > 0 else { return }
            try? await Task.sleep(for: .seconds(2.5))
            // A newer save started its own wait.
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) {
                showsConfirmation = false
            }
        }
    }

    // MARK: - Parts

    private var field: some View {
        let isEmpty = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: Spacing.tight) {
            styled(TextField(placeholder, text: $draft,
                             prompt: Text(placeholder).foregroundStyle(Palette.muted),
                             axis: .vertical))
                .foregroundStyle(Palette.text)
                .focused($isFocused)
                .submitLabel(.done)
                .lineLimit(lines)
                .onAppear {
                    // Asked for once more when the field is really there, in case the first
                    // request came too early.
                    isFocused = true
                }
            if isEmpty, let emptiedHint {
                Text(polish: emptiedHint)
                    .hintText()
            }
        }
        .fieldBox()
        .onChange(of: draft) { oldValue, newValue in
            if let finished = Self.textOnReturnKey(old: oldValue, new: newValue) {
                draft = finished
                finish(typed: finished)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch emptyStyle {
        case .action:
            StarActionButton(emptyLine, size: .regular) {
                open()
            }
        case .invitation:
            invitation
        }
    }

    /// Where her text will be: the size of the open field, with a dashed edge.
    private var invitation: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        return Button {
            open()
        } label: {
            HStack(spacing: Spacing.item) {
                OrganicStar()
                    .fill(Palette.accentDim)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text(polish: emptyLine)
                    .font(.body)
                    .foregroundStyle(Palette.text2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Spacing.item + 2)
            .frame(maxWidth: .infinity, minHeight: TapSize.large, alignment: .leading)
            .background {
                shape.fill(Color.white.opacity(0.03))
            }
            .overlay {
                shape.strokeBorder(Palette.accent.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .contentShape(shape)
        }
        .buttonStyle(TilePressStyle())
    }

    @ViewBuilder
    private var savedText: some View {
        if serif {
            tappable(serifText)
        } else {
            tappable(ListRow(text, detail: detail))
        }
    }

    /// Her own sentence, large and in italics.
    private var serifText: some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            Text(polish: text)
                .displayFont(20, italic: true, relativeTo: .body)
                .foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .rowDetail()
            }
        }
        .padding(.vertical, Spacing.hairline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Tap to correct it; with `delete`, swipe left to remove it.
    @ViewBuilder
    private func tappable(_ content: some View) -> some View {
        if let delete {
            content.swipeToDelete(label: deleteLabel, onTap: { open() }) {
                delete(key)
            }
        } else {
            content
                .contentShape(Rectangle())
                .onTapGesture {
                    open()
                }
                .accessibilityAddTraits(.isButton)
        }
    }

    @ViewBuilder
    private func styled(_ content: some View) -> some View {
        if serif {
            content.displayFont(20, italic: true, relativeTo: .body)
        } else {
            content.font(.body)
        }
    }

    // MARK: - Editing

    private func open() {
        originalText = text
        draft = text
        showsConfirmation = false
        editingKey = key
        isFocused = true
    }

    /// Saves the open field – or `typed`, the text it is about to hold – and closes it. When the
    /// store refuses, her words stay in the field, unless the field has to close (another day,
    /// another screen).
    private func finish(typed: String? = nil, force: Bool = false) {
        guard let target = editingKey else { return }
        let trimmed = (typed ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        let isUnchanged = trimmed == originalText
        let isSaved = !isUnchanged && save(trimmed, target)
        if isUnchanged || isSaved || force {
            editingKey = nil
            draft = ""
        }
        isFocused = false
        if isSaved && !trimmed.isEmpty && confirmation != nil {
            withAnimation(.smooth) {
                showsConfirmation = true
            }
            saves += 1
        }
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
