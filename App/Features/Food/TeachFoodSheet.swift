import SwiftUI
import UIKit
import Combine
import AboutHerCore

/// "nowy produkt": she gives the values of a product once and the app remembers them – also for
/// the meals already logged with it. "Twój produkt": one of hers, opened again to correct it.
///
/// The sheet saves itself when it closes (a swipe down) and when the app goes to the background,
/// but only when something changed and everything adds up. While something she changed can't be
/// saved yet, the sheet stays open, a gentle line says what is missing, and "zamknij bez zmian"
/// at the top leaves everything as it was saved.
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
    @ScaledMetric(relativeTo: .title3) private var fieldWidth: CGFloat = FoodFieldSize.width

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
        /// Labels give the values per 100 g, as the card says; "na porcję" is one tap away.
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

    /// The card whose line shows a hint.
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
        FoodSheetPage {
            ScreenHeader(title: title,
                         subtitle: existing == nil
                            ? "zapamiętam go i policzę też w posiłkach, które już zapisałaś"
                            : "gdy coś tu poprawisz, przeliczę też posiłki, które już zapisałaś")
            if isBlocked {
                FoodUnsavedNote {
                    isCancelled = true
                    dismiss()
                }
            }
            Card {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    FoodTextField("nazwa", text: $draft.name)
                    FoodTextField("inne formy", text: $draft.otherForms, placeholder: "np. pierogów, pierogami")
                    problemLine(for: .name)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    SectionHeader("porcja", subtitle: "tyle policzę, gdy napiszesz samą nazwę, bez ilości")
                    VStack(spacing: Spacing.tight) {
                        unitRow
                        FoodNumberRow("waga porcji", text: $draft.portionGrams, placeholder: "np. 250", unit: "g")
                    }
                    problemLine(for: .portion)
                }
            }
            Card {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    SectionHeader(existing == nil ? "wartości" : "wartości na 100 g",
                                  subtitle: "znajdziesz je na opakowaniu, zwykle na 100 g")
                    // Her own product opens with its values per 100 g, filled in by me: a switch would
                    // only change what those same numbers mean, so it is there for a new product only.
                    if existing == nil {
                        ChoiceTiles(options: [Basis.per100g, Basis.portion],
                                    selection: draft.basis,
                                    columns: 2,
                                    label: { $0 == .per100g ? "na 100 g" : "na porcję" },
                                    onSelect: { draft.basis = $0 })
                    }
                    VStack(spacing: Spacing.tight) {
                        FoodNumberRow("kcal", text: $draft.kcal, placeholder: "0", unit: "kcal")
                        FoodNumberRow("białko", text: $draft.protein, placeholder: "0", unit: "g")
                        FoodNumberRow("węglowodany", text: $draft.carbs, placeholder: "0", unit: "g")
                        FoodNumberRow("tłuszcz", text: $draft.fat, placeholder: "0", unit: "g")
                    }
                    if let item = readyItem {
                        ConfirmationNote(text: portionSummary(item))
                    }
                    problemLine(for: .values)
                }
            }
        }
        // A change that can't be saved yet keeps the sheet open, so nothing she typed is lost
        // by a swipe; "zamknij bez zmian" still closes it.
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

    // MARK: - Parts

    /// "porcja to [porcja ⌃⌄]": the unit a bare name counts as, picked from a menu.
    private var unitRow: some View {
        HStack(spacing: Spacing.item) {
            Text("porcja to")
                .rowTitle()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            Menu {
                Picker("porcja to", selection: $draft.portionUnit) {
                    ForEach(PortionUnit.allCases, id: \.self) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            } label: {
                HStack(spacing: Spacing.tight) {
                    Text(draft.portionUnit.label)
                        .font(.body)
                        .foregroundStyle(Palette.text)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
                .fieldBox()
            }
            .frame(width: fieldWidth)
            .accessibilityLabel("porcja to")
            .accessibilityValue(Text(draft.portionUnit.label))
        }
        .frame(minHeight: TapSize.large)
    }

    /// The first thing that still needs her, under the card it belongs to.
    @ViewBuilder
    private func problemLine(for part: Part) -> some View {
        if let hint = hintText(for: part) {
            Text(polish: hint)
                .font(.footnote)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func hintText(for part: Part) -> String? {
        guard case .needs(let problemPart, let hint) = outcome, problemPart == part else { return nil }
        return hint
    }

    /// The product, once everything adds up.
    private var readyItem: FoodItem? {
        if case .ready(let item) = outcome {
            return item
        }
        return nil
    }

    /// "1 porcja to 250 g, ok. 300 kcal".
    private func portionSummary(_ item: FoodItem) -> String {
        let portion = item.defaultPortion
        let kcal = FoodFormat.whole(item.macros(grams: portion.grams).kcal)
        return "1 \(portion.unit.label) to \(FoodFormat.compact(portion.grams)) g, ok. \(kcal) kcal"
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
