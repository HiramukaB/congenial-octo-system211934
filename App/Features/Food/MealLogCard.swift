import SwiftUI
import AboutHerCore

/// "co zjadłaś": tap "dopisz posiłek", type in plain Polish, and it saves itself – no confirm button.
/// Each meal is one compact line – her words and its kcal. A tap on a meal opens it in the same
/// field, in its place, with what I counted above the text; a swipe left deletes it.
struct MealLogCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let day: LocalDate
    /// Opens the sheet that teaches the app an unknown product.
    let onTeach: (String) -> Void
    /// Opens one of her own products, to correct what she taught the app.
    let onEditFood: (FoodItem) -> Void
    /// Scrolls the screen so the open field (`editorID`) sits just above the keyboard.
    var keepEditorInSight: () -> Void = {}

    /// The scroll id of the open field, for `keepEditorInSight`.
    static let editorID = "meal-editor"
    /// Longer than this (a pasted page), the text is counted only when it is saved, so typing
    /// never waits for the live preview.
    static let previewLimit = 1000

    /// What the field is writing; nil while it is closed.
    @State private var editing: Editing? = nil
    @State private var draft = ""
    @FocusState private var isFocused: Bool
    /// Counts the meals saved here, for one soft haptic each.
    @State private var savedMeals = 0

    /// A new meal, or a logged one she tapped, and the day it belongs to.
    struct Editing {
        /// nil for a new meal.
        var mealID: UUID?
        var day: LocalDate
        /// The meal's text when she opened it; an unchanged text isn't saved again.
        var originalText: String
    }

    var body: some View {
        let entries = store.data.meals(on: day)
        let rows = rowsAround(entries)
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("co zjadłaś", subtitle: day == store.today ? nil : PolishDate.long(day))
                // On its own line under the heading, where the field for a new meal opens, so the
                // label always fits on one line. Without meals the empty state offers it instead.
                if editing == nil && !entries.isEmpty {
                    StarActionButton("dopisz posiłek", size: .regular, action: startNewMeal)
                }
                // The field is one and the same view wherever it opens – above the meals for a new
                // one, in place of a meal she tapped – so the keyboard stays up from meal to meal.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.before.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            RowDivider()
                        }
                        row(entry)
                    }
                    if let editing {
                        editor(editing)
                            .padding(.vertical, Spacing.tight)
                            .id(Self.editorID)
                            // The keyboard keeps in sight only the line she is typing, so when the
                            // preview above it gains a line (or the text a new row) the field would
                            // slip under it.
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { _ in
                                keepEditorInSight()
                            }
                    } else if entries.isEmpty {
                        emptyState
                    }
                    ForEach(Array(rows.after.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            RowDivider()
                        }
                        row(entry)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: savedMeals)
        .onChange(of: draft) { oldValue, newValue in
            handleLineBreaks(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: isFocused) { _, focused in
            // The keyboard went away (dragged down, another sheet, another tab): she is done.
            if !focused {
                finishEditing()
            }
        }
        .onChange(of: day) {
            // Another day is shown (her switch, midnight, leaving the tab): what she typed is saved
            // to the day it was typed for.
            finishEditing(force: true)
        }
        .onChange(of: scenePhase) { _, phase in
            // In the background the app may be ended at any time: save the field and the file now.
            if phase == .background {
                finishEditing()
                store.saveNow()
            }
        }
    }

    // MARK: - Parts

    /// No meals yet: a warm line and "dopisz posiłek" under it.
    private var emptyState: some View {
        EmptyState(title: day == store.today
                   ? "tu pojawi się to, co dziś zjesz"
                   : "z tego dnia nie mam zapisanych posiłków",
                   actionTitle: "dopisz posiłek",
                   action: startNewMeal)
    }

    private func row(_ entry: MealEntry) -> some View {
        MealRow(entry: entry, ownFoods: ownFoods(in: entry), onTeach: onTeach, onEditFood: onEditFood)
            .swipeToDelete(label: "usuń posiłek", onTap: { edit(entry) }) {
                store.removeMeal(entry.id, on: day)
            }
    }

    /// The hint and the live preview sit above the text: the keyboard keeps the line she is typing
    /// just in sight and covers whatever is below it.
    private func editor(_ editing: Editing) -> some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            Text(polish: hint(for: editing))
                .hintText()
            preview
            TextField("np. dwa jajka, kromka chleba, kawa z mlekiem", text: $draft, axis: .vertical)
                .font(.body)
                .foregroundStyle(Palette.text)
                .focused($isFocused)
                .submitLabel(.done)
                .lineLimit(1...6)
                .accessibilityIdentifier("meal-field")
                .onAppear {
                    // Asked for once more when the field is really there, in case the first request
                    // came too early.
                    isFocused = true
                }
        }
        .fieldBox()
    }

    /// Live preview of what I understand, while she types: each product, then the whole meal, and a
    /// hairline that sets her own words apart from it.
    @ViewBuilder private var preview: some View {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > Self.previewLimit {
            Text(polish: "tak długi tekst policzę dopiero po zapisaniu")
                .hintText()
            FieldDivider()
        } else if !trimmed.isEmpty {
            let parsed = store.mealParser.parse(trimmed)
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                ForEach(Array(parsed.items.enumerated()), id: \.offset) { _, item in
                    Text(FoodFormat.itemLine(item))
                        .font(.footnote)
                        .foregroundStyle(Palette.text2)
                }
                if !parsed.items.isEmpty {
                    Text(verbatim: "razem: \(FoodFormat.macrosLine(parsed.totals))")
                        .font(.footnote.weight(.medium).monospacedDigit())
                        .foregroundStyle(Palette.text)
                        .padding(.top, Spacing.hairline)
                }
                if !parsed.unknown.isEmpty {
                    Text("nie znam jeszcze: \(parsed.unknown.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                }
                if parsed.items.isEmpty && parsed.unknown.isEmpty {
                    // So far only the meal, a time or who she ate with ("obiad:", "8:30").
                    Text(polish: "nie widzę tu jeszcze nic do policzenia")
                        .hintText()
                }
            }
            .accessibilityElement(children: .combine)
            FieldDivider()
        }
    }

    private func hint(for editing: Editing) -> String {
        // The return key shows a checkmark rather than a word, so the hint speaks of the keyboard.
        guard editing.mealID != nil else {
            return "zapiszę to, gdy schowasz klawiaturę"
        }
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "pusty tekst nic nie zmieni – posiłek usuniesz, przesuwając go w lewo"
        }
        return "zapiszę poprawkę, gdy schowasz klawiaturę"
    }

    /// The meals above and below the field. A meal she is correcting is replaced by the field;
    /// a new meal is written above them all.
    private func rowsAround(_ entries: [MealEntry]) -> (before: [MealEntry], after: [MealEntry]) {
        guard let id = editing?.mealID, let index = entries.firstIndex(where: { $0.id == id }) else {
            return ([], entries)
        }
        return (Array(entries[..<index]), Array(entries[(index + 1)...]))
    }

    /// Her own products in a meal, each once, as they are stored now.
    private func ownFoods(in entry: MealEntry) -> [FoodItem] {
        var seen = Set<String>()
        return entry.items.compactMap { item in
            guard item.foodID.hasPrefix("user-"), seen.insert(item.foodID).inserted else { return nil }
            return store.userFood(id: item.foodID)
        }
    }

    // MARK: - Editing

    private func startNewMeal() {
        guard editing == nil else { return }
        open(Editing(mealID: nil, day: day, originalText: ""), text: "")
    }

    /// A tap on a logged meal opens it in the field, in its place. What the field held is saved first.
    private func edit(_ entry: MealEntry) {
        if editing != nil {
            guard save(draft) else { return }
        }
        open(Editing(mealID: entry.id, day: day, originalText: entry.text), text: entry.text)
    }

    private func open(_ target: Editing, text: String) {
        editing = target
        draft = text
        isFocused = true
    }

    /// Saves the field and closes it: on "gotowe", when the keyboard goes, on another day and when
    /// the app goes to the background. If her data can't be written right now (the store says why),
    /// the text stays in the field – except on another day, where the field has to close.
    private func finishEditing(text: String? = nil, force: Bool = false) {
        guard editing != nil else { return }
        if save(text ?? draft) || force {
            editing = nil
            draft = ""
        }
        isFocused = false
    }

    /// Writes the field to the store. Returns `false` only when the store refused it.
    private func save(_ text: String) -> Bool {
        guard let editing else { return true }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // An emptied field changes nothing; a meal is deleted with a swipe.
        guard !trimmed.isEmpty else { return true }
        // The date can move back (a time zone to the west): a new meal then goes to the day it is now.
        let newMealDay = Swift.min(editing.day, store.today)
        guard let id = editing.mealID else {
            return counted(store.logMeal(trimmed, on: newMealDay))
        }
        guard trimmed != editing.originalText else { return true }
        if store.data.meals(on: editing.day).contains(where: { $0.id == id }) {
            return counted(store.replaceMeal(id, text: trimmed, on: editing.day))
        }
        // The meal isn't there any more: keep her words as a new meal rather than lose them.
        return counted(store.logMeal(trimmed, on: newMealDay))
    }

    /// Passes the store's answer on, with a soft haptic when the meal was saved.
    private func counted(_ saved: Bool) -> Bool {
        if saved {
            savedMeals += 1
        }
        return saved
    }

    /// The return key of a multi-line field inserts a line break: a single one means "gotowe".
    /// A pasted list keeps its lines as separate items and stays open, so she can look it over.
    private func handleLineBreaks(oldValue: String, newValue: String) {
        guard newValue.contains(where: \.isNewline) else { return }
        let withoutBreaks = newValue.filter { !$0.isNewline }
        let breaks = newValue.filter(\.isNewline).count
        if breaks == 1, withoutBreaks != oldValue, let lineBreak = newValue.firstIndex(where: \.isNewline) {
            let before = newValue[..<lineBreak]
            let after = newValue[newValue.index(after: lineBreak)...]
            // ✓ over selected text replaced the selection with the line break: it still only means
            // "gotowe", so her text is saved as it was.
            if before.count + after.count < oldValue.count, oldValue.hasPrefix(before), oldValue.hasSuffix(after) {
                draft = oldValue
                finishEditing(text: oldValue)
                return
            }
        }
        let isReturnKey = breaks == 1
            && (withoutBreaks == oldValue
                // An autocorrection can land together with the return key at the end of the text.
                || (newValue.last?.isNewline == true && newValue.count - oldValue.count <= 2))
        if isReturnKey {
            draft = withoutBreaks
            finishEditing(text: withoutBreaks)
        } else {
            draft = MealLogCard.joiningLines(newValue)
        }
    }

    /// "owsianka⏎banan⏎kawa z mlekiem" → "owsianka, banan, kawa z mlekiem": the parser reads each
    /// comma-separated part as a food of its own. List bullets, list numbers and stray commas at
    /// the ends go.
    static func joiningLines(_ text: String) -> String {
        let edges = CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",;•·*-–—"))
        return text.split(whereSeparator: \.isNewline)
            // "1) owsianka", "2. banan", "3: kawa": a list number, not an amount ("8:30", "1.5 kg" stay).
            .map { $0.replacingOccurrences(of: #"^\s*\d{1,2}[.):](?!\d)"#, with: "", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: edges) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// One logged meal as a compact row: her words on one line and the kcal I counted; the whole text
/// and what I counted open on a tap. Under it – only when they are there – the products I don't
/// know yet and her own products, each a link.
struct MealRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: MealEntry
    /// Her own products in this meal, which she can open to correct.
    let ownFoods: [FoodItem]
    let onTeach: (String) -> Void
    let onEditFood: (FoodItem) -> Void

    var body: some View {
        let unknown = MealRow.unique(entry.unknown)
        let ownLabel = ownFoods.count == 1 ? "Twój produkt:" : "Twoje produkty:"
        let flow = FlowLayout()
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
                Text(entry.text)
                    .rowTitle()
                    // One line, so the day reads at a glance; at the largest text sizes a few,
                    // so her words stay readable.
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !entry.items.isEmpty {
                    Text(verbatim: "\(FoodFormat.whole(entry.totals.kcal)) kcal")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.text2)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .combine)
            if entry.items.isEmpty && entry.unknown.isEmpty {
                // Only the meal, a time or who she ate with ("obiad", "8:30"): nothing was counted.
                Text(polish: "nic tu nie policzyłam")
                    .rowDetail()
            }
            if !unknown.isEmpty {
                flow {
                    Text("nie znam jeszcze:")
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                    ForEach(unknown, id: \.self) { name in
                        Button(name) { onTeach(name) }
                            .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
                            .accessibilityHint("dopisz wartości tego produktu")
                    }
                }
            }
            if !ownFoods.isEmpty {
                flow {
                    Text(ownLabel)
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                    ForEach(ownFoods) { food in
                        Button(food.name) { onEditFood(food) }
                            .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
                            .accessibilityHint("popraw wartości tego produktu")
                    }
                }
            }
        }
        .padding(.vertical, Spacing.item)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Each name once, in the order she wrote them.
    private static func unique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}

/// A hairline inside the open field, between what I counted and her words. `RowDivider` would
/// vanish on the field's warm background, so this one takes a touch of the accent.
private struct FieldDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.accent.opacity(0.18))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
