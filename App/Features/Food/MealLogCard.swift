import SwiftUI
import AboutHerCore

/// "co zjadłaś": tap, type in plain Polish, and it saves itself – no confirm button.
/// A tap on a logged meal opens it in the same field, in its place, to correct it.
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).sectionTitle()
                    Spacer()
                    if editing == nil {
                        StarButton(label: "dopisz posiłek", prominent: true, action: startNewMeal)
                    }
                }
                // The field is one and the same view wherever it opens – above the meals for a new
                // one, in place of a meal she tapped – so the keyboard stays up from meal to meal.
                ForEach(rows.before) { entry in
                    row(entry)
                }
                if let editing {
                    editor(editing)
                        .id(Self.editorID)
                        // The keyboard keeps in sight only the line she is typing, so when the preview
                        // above it gains a line (or the text a new row) the field would slip under it.
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { _ in
                            keepEditorInSight()
                        }
                } else if entries.isEmpty {
                    emptyState
                }
                ForEach(rows.after) { entry in
                    row(entry)
                }
            }
        }
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

    private var title: String {
        day == store.today ? "co zjadłaś" : "co zjadłaś · \(PolishDate.dayMonth(day))"
    }

    private var emptyState: some View {
        Button(action: startNewMeal) {
            Text(polish: day == store.today
                 ? "tu pojawi się to, co zjesz – dotknij, żeby dopisać"
                 : "nic tu jeszcze nie ma – dotknij, żeby dopisać, co zjadłaś")
                .bodyText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(polish: hint(for: editing))
                .font(.caption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            preview
            TextField("np. trzy jajka, łyżeczka masła, kromka chleba żytniego", text: $draft, axis: .vertical)
                .font(.subheadline)
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
    }

    /// Live preview of what I understand, while she types.
    @ViewBuilder private var preview: some View {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > Self.previewLimit {
            Text(polish: "tak długi tekst policzę dopiero po zapisaniu")
                .font(.caption)
                .foregroundStyle(Palette.muted)
        } else if !trimmed.isEmpty {
            let parsed = store.mealParser.parse(trimmed)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(parsed.items.enumerated()), id: \.offset) { _, item in
                    Text(FoodFormat.itemLine(item))
                        .font(.caption)
                        .foregroundStyle(Palette.text2)
                }
                if !parsed.unknown.isEmpty {
                    Text("nie znam jeszcze: \(parsed.unknown.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
                if parsed.items.isEmpty && parsed.unknown.isEmpty {
                    // So far only the meal, a time or who she ate with ("obiad:", "8:30").
                    Text(polish: "nie widzę tu jeszcze nic do policzenia")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func hint(for editing: Editing) -> String {
        // The return key shows a checkmark rather than a word, so the hint speaks of the keyboard.
        guard editing.mealID != nil else {
            return "zapiszę to, gdy schowasz klawiaturę"
        }
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "pusty tekst niczego nie zmieni – posiłek usuniesz, przesuwając go w lewo"
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
            return store.logMeal(trimmed, on: newMealDay)
        }
        guard trimmed != editing.originalText else { return true }
        if store.data.meals(on: editing.day).contains(where: { $0.id == id }) {
            return store.replaceMeal(id, text: trimmed, on: editing.day)
        }
        // The meal isn't there any more: keep her words as a new meal rather than lose them.
        return store.logMeal(trimmed, on: newMealDay)
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

/// One logged meal: what she wrote, what I counted, its values, and links to the products I don't
/// know yet or that she taught me.
struct MealRow: View {
    let entry: MealEntry
    /// Her own products in this meal, which she can open to correct.
    let ownFoods: [FoodItem]
    let onTeach: (String) -> Void
    let onEditFood: (FoodItem) -> Void

    var body: some View {
        let unknown = MealRow.unique(entry.unknown)
        let ownLabel = ownFoods.count == 1 ? "Twój produkt:" : "Twoje produkty:"
        let flow = FlowLayout()
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !entry.items.isEmpty {
                    // What was counted, so a food I missed or misread shows at a glance.
                    Text(MealRow.countedLine(entry.items))
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if entry.items.isEmpty && entry.unknown.isEmpty {
                    // Only the meal, a time or who she ate with ("obiad", "8:30"): nothing was counted.
                    Text(polish: "nic tu nie policzyłam – dotknij, żeby dopisać, co zjadłaś")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(FoodFormat.macrosLine(entry.totals))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
            }
            .accessibilityElement(children: .combine)
            if !unknown.isEmpty {
                flow {
                    Text("nie znam jeszcze:")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                    ForEach(unknown, id: \.self) { name in
                        Button(name) { onTeach(name) }
                            .buttonStyle(LinkButtonStyle(font: .caption.weight(.medium)))
                            .accessibilityHint("dopisz wartości tego produktu")
                    }
                }
            }
            if !ownFoods.isEmpty {
                flow {
                    Text(ownLabel)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                    ForEach(ownFoods) { food in
                        Button(food.name) { onEditFood(food) }
                            .buttonStyle(LinkButtonStyle(font: .caption.weight(.medium)))
                            .accessibilityHint("popraw wartości tego produktu")
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What was counted, in short: "jajko × 3 · chleb żytni × 2 · masło · łosoś 150 g".
    static func countedLine(_ items: [ParsedItem]) -> String {
        items.map { item in
            var part = item.foodName
            if item.unit == nil {
                part += " \(FoodFormat.whole(item.grams)) g"
            } else if abs(item.amount - 1) > 0.001 {
                part += " × " + amountText(item.amount)
            }
            if item.isGuess {
                part += " (?)"
            }
            return part
        }
        .joined(separator: " · ")
    }

    /// "3", "1,5", "0,25".
    private static func amountText(_ value: Double) -> String {
        let decimals: Int
        if abs(value - value.rounded()) < 0.001 {
            decimals = 0
        } else if abs(value * 10 - (value * 10).rounded()) < 0.01 {
            decimals = 1
        } else {
            decimals = 2
        }
        return FoodFormat.number(value, decimals: decimals)
    }

    /// Each name once, in the order she wrote them.
    private static func unique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}
