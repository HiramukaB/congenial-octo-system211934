import SwiftUI
import UIKit
import Combine
import AboutHerCore

/// "nowy produkt": she gives the values of a product once and the app remembers them – also for
/// the meals already logged with it. "Twój produkt": one of hers, opened again to correct it.
///
/// The sheet saves itself when it closes (swiped down or "gotowe") and when the app goes to the
/// background, but only when something changed and everything adds up. "anuluj" throws away
/// what she typed after the last save. While something she changed can't be saved yet, the
/// sheet stays open and a gentle line says what is missing.
struct TeachFoodSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The words she typed in a meal; the starting name of a new product.
    let suggestedName: String
    /// Her product being corrected; nil when teaching a new one.
    let existing: FoodItem?

    @State private var draft: Draft
    /// The form as it opened, or as it was last saved: nothing is saved unless something differs from it.
    @State private var initial: Draft
    @State private var newID = "user-" + UUID().uuidString.lowercased()
    @State private var isCancelled = false

    /// No food has more than 900 kcal in 100 g (pure fat).
    private static let maxKcalPer100: Double = 900
    /// Values for a small portion are rounded on the label, so per 100 g they can come out a
    /// little higher than they really are.
    private static let portionRoundingAllowance: Double = 50
    /// A single portion heavier than this is a typo.
    private static let maxPortionGrams: Double = 3000

    init(suggestedName: String, existing: FoodItem? = nil) {
        self.suggestedName = suggestedName
        self.existing = existing
        let start: Draft
        if let existing {
            start = Draft.editing(existing)
        } else {
            start = Draft(name: suggestedName)
        }
        _draft = State(initialValue: start)
        _initial = State(initialValue: start)
    }

    enum Basis: Hashable {
        case portion, per100g
    }

    /// Everything she can type, as text, exactly as in the fields.
    private struct Draft: Equatable {
        var name = ""
        var otherForms = ""
        /// Labels give the values per 100 g, as the footer says; "na porcję" is one tap away.
        var basis: Basis = .per100g
        var portionUnit: PortionUnit = .serving
        /// Empty at first, so she gives the real weight of her portion.
        var portionGrams = ""
        var kcal = ""
        var protein = ""
        var carbs = ""
        var fat = ""

        /// Her saved product, with its values per 100 g.
        static func editing(_ item: FoodItem) -> Draft {
            Draft(name: item.name,
                  otherForms: item.aliases.joined(separator: ", "),
                  basis: .per100g,
                  portionUnit: item.defaultPortion.unit,
                  portionGrams: FoodFormat.compact(item.defaultPortion.grams),
                  kcal: FoodFormat.compact(item.per100.kcal),
                  protein: FoodFormat.compact(item.per100.protein),
                  carbs: FoodFormat.compact(item.per100.carbs),
                  fat: FoodFormat.compact(item.per100.fat))
        }
    }

    /// The section whose footer shows a hint.
    private enum Part {
        case name, portion, values
    }

    /// What she typed, as a product – or the first thing that still needs her, worded as
    /// guidance, so it also reads well while she is still typing.
    private enum Outcome {
        case ready(FoodItem)
        case needs(Part, String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("nazwa", text: $draft.name)
                    TextField("inne formy, np. pierogów, pierogami", text: $draft.otherForms)
                } footer: {
                    footer(existing == nil
                           ? "podaj wartości raz, a zapamiętam je na przyszłość. Policzę je też w posiłkach, które już zapisałaś"
                           : "gdy coś tu poprawisz, przeliczę też posiłki, które już zapisałaś",
                           part: .name)
                }
                Section {
                    Picker("porcja to", selection: $draft.portionUnit) {
                        ForEach(PortionUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    valueField("waga porcji (g)", text: $draft.portionGrams, placeholder: "np. 250")
                } header: {
                    Text("porcja")
                        .textCase(nil)
                } footer: {
                    footer("tyle policzę, gdy napiszesz samą nazwę, bez ilości", part: .portion)
                }
                Section {
                    // Her own product opens with its values per 100 g, filled in by me: a switch would
                    // only change what those same numbers mean, so it is there for a new product only.
                    if existing == nil {
                        Picker("wartości podaję", selection: $draft.basis) {
                            Text("na porcję").tag(Basis.portion)
                            Text("na 100 g").tag(Basis.per100g)
                        }
                        .pickerStyle(.segmented)
                    }
                    valueField("kcal", text: $draft.kcal, placeholder: "0")
                    valueField("białko (g)", text: $draft.protein, placeholder: "0")
                    valueField("węglowodany (g)", text: $draft.carbs, placeholder: "0")
                    valueField("tłuszcz (g)", text: $draft.fat, placeholder: "0")
                } header: {
                    Text(verbatim: existing == nil ? "wartości" : "wartości na 100 g")
                        .textCase(nil)
                } footer: {
                    footer(valuesNote, part: .values)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("anuluj") {
                        isCancelled = true
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Closing saves (see onDisappear), so "gotowe" only closes.
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("gotowe")
                    .disabled(isBlocked)
                }
            }
        }
        .presentationDetents([.large])
        // A change that can't be saved yet keeps the sheet open, so nothing she typed is lost
        // by a swipe; "anuluj" still closes it.
        .interactiveDismissDisabled(isBlocked)
        .onDisappear {
            if !isCancelled {
                commit()
            }
        }
        // In the background the app may be ended before the sheet ever closes: what is ready is
        // saved and written now, and from then on only a later change is saved again.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            guard !isCancelled, !takesInAnotherProduct else { return }
            let saved = commit()
            store.saveNow()
            if saved {
                initial = draft
            }
        }
    }

    private var title: String {
        existing == nil ? "nowy produkt" : "Twój produkt"
    }

    private func valueField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        LabeledContent(label) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    /// The section's own note and, when the first problem is in this section, a line about it.
    private func footer(_ note: String, part: Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(polish: note)
            if let hint = hintText(for: part) {
                Text(polish: hint)
                    .foregroundStyle(Palette.accent)
            }
        }
    }

    private func hintText(for part: Part) -> String? {
        guard case .needs(let problemPart, let hint) = outcome, problemPart == part else { return nil }
        return hint
    }

    /// Where the values come from and, once everything adds up, what one portion counts as.
    private var valuesNote: String {
        var note = "wartości znajdziesz na opakowaniu – zwykle na 100 g"
        if case .ready(let item) = outcome {
            let portion = item.defaultPortion
            let kcal = FoodFormat.whole(item.macros(grams: portion.grams).kcal)
            note += ". 1 \(portion.unit.label) to \(FoodFormat.compact(portion.grams)) g, ok. \(kcal) kcal"
        }
        return note
    }

    // MARK: - Saving

    private var hasChanges: Bool {
        draft != initial
    }

    private var isReady: Bool {
        if case .ready = outcome {
            return true
        }
        return false
    }

    /// Something changed but can't be saved yet.
    private var isBlocked: Bool {
        hasChanges && !isReady
    }

    /// Saves under the same id when correcting, so teachFood replaces the old product and counts
    /// the meals that used it again. A new product keeps its id too, so saving it again after a
    /// save in the background corrects it rather than adding it twice. Opening and closing without
    /// a change writes nothing. Returns `true` when the store saved it.
    @discardableResult
    private func commit() -> Bool {
        guard hasChanges, case .ready(let item) = outcome else { return false }
        return store.teachFood(item)
    }

    /// Another of her products has this name, so saving takes that one in (AppData.teachFood) and
    /// no later change of the name undoes it. In the background, where the name may be only half
    /// typed, this waits for the close.
    private var takesInAnotherProduct: Bool {
        guard case .ready(let item) = outcome else { return false }
        let name = FoodText.normalized(item.name)
        return store.data.userFoods.contains { $0.id != item.id && FoodText.normalized($0.name) == name }
    }

    private var outcome: Outcome {
        let cleanName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanName.isEmpty else {
            return .needs(.name, "jeszcze potrzebuję nazwy produktu")
        }

        let portionText = draft.portionGrams.trimmingCharacters(in: .whitespaces)
        guard !portionText.isEmpty else {
            return .needs(.portion, "jeszcze potrzebuję wagi porcji w gramach, np. 250")
        }
        guard let portionWeight = FoodFormat.parseNumber(portionText),
              portionWeight > 0, portionWeight <= Self.maxPortionGrams
        else {
            return .needs(.portion, "wagę porcji wpisz w gramach, np. 250")
        }

        let kcalText = draft.kcal.trimmingCharacters(in: .whitespaces)
        guard !kcalText.isEmpty else {
            return .needs(.values, "jeszcze potrzebuję kcal")
        }
        guard let kcal = FoodFormat.parseNumber(kcalText), kcal >= 0 else {
            return .needs(.values, "kcal wpisz jako liczbę, np. 120")
        }
        // An empty field counts as 0 g; anything else must be a number.
        let gramFields = [(draft.protein, "białko"), (draft.carbs, "węglowodany"), (draft.fat, "tłuszcz")]
        var grams: [Double] = []
        for (text, label) in gramFields {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                grams.append(0)
                continue
            }
            guard let value = FoodFormat.parseNumber(trimmed), value >= 0 else {
                return .needs(.values, "\(label) wpisz w gramach, np. 12,5")
            }
            grams.append(value)
        }

        // "na porcję" only says what the numbers are for: they are stored per 100 g.
        let factor = draft.basis == .portion ? 100 / portionWeight : 1
        let per100 = Macros(kcal: kcal, protein: grams[0], carbs: grams[1], fat: grams[2]).scaled(by: factor)
        // Saved per portion, her product may hold up to 950 kcal per 100 g; opened again it shows that
        // value per 100 g, which stays acceptable while she leaves it as it is.
        let keepsSavedKcal = existing != nil && draft.kcal == initial.kcal
        let kcalLimit = draft.basis == .portion || keepsSavedKcal
            ? Self.maxKcalPer100 + Self.portionRoundingAllowance
            : Self.maxKcalPer100
        guard per100.kcal <= kcalLimit else {
            return .needs(.values, draft.basis == .portion
                ? "na 100 g wychodzi ponad 900 kcal, a tyle nie ma żaden produkt – sprawdź, proszę, kcal i wagę porcji"
                : "ponad 900 kcal na 100 g nie ma żaden produkt – sprawdź, proszę, tę liczbę")
        }

        var aliases: [String] = []
        func addForm(_ form: String) {
            let clean = form.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !clean.isEmpty, clean != cleanName, !aliases.contains(clean) {
                aliases.append(clean)
            }
        }
        for form in draft.otherForms.split(separator: ",") {
            addForm(String(form))
        }
        let portion = Portion(unit: draft.portionUnit, grams: portionWeight)

        if var item = existing {
            // A new name keeps the old one as another form, so meals logged with it still count.
            addForm(item.name)
            item.name = cleanName
            item.aliases = aliases
            item.per100 = per100
            item.portions = [portion]
            item.defaultPortion = portion
            return .ready(item)
        }
        // The words she actually typed, so the meal that started this is recognised too.
        addForm(suggestedName)
        return .ready(FoodItem(id: newID, name: cleanName, aliases: aliases, category: .other,
                               per100: per100, portions: [portion], defaultPortion: portion))
    }
}
