import SwiftUI
import UIKit
import AboutHerCore

/// How quickly she would like to go: the deficit below what she burns, as in "Twoje cele dzienne".
nonisolated enum WelcomePace: Double, CaseIterable {
    case maintain = 0
    case gentle = 250
    case moderate = 400

    var label: String {
        switch self {
        case .maintain: "utrzymanie wagi"
        case .gentle: "łagodnie, ok. −250 kcal"
        case .moderate: "umiarkowanie, ok. −400 kcal"
        }
    }

    /// The pace nearest to a saved deficit.
    static func closest(to deficit: Double) -> WelcomePace {
        allCases.min { abs($0.rawValue - deficit) < abs($1.rawValue - deficit) } ?? .gentle
    }
}

/// A field of her own targets.
nonisolated enum WelcomeTargetField: Hashable {
    case kcal, protein, carbs, fat
}

/// "Twoje cele na dzień": the daily targets from her numbers, shown simply – the kcal large, the
/// rest in one line – with how much she moves and her pace to adjust them. Or her own numbers
/// ("wolę wpisać własne"), which also works without the numbers about her. Every change is saved
/// at once.
struct WelcomeTargetsStep: View {
    @Environment(AppStore.self) private var store
    @Binding var memory: WelcomeMemory
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var showsPace = false
    @FocusState private var focus: WelcomeTargetField?

    var body: some View {
        let profile = store.data.nutritionProfile
        let isManual = isManualSetting
        WelcomePage(step: .targets,
                    title: "Twoje cele na dzień",
                    subtitle: subtitle(hasProfile: profile != nil, isManual: isManual),
                    canSkip: store.targets == nil,
                    onBack: onBack,
                    onNext: moveOn,
                    onSkip: skip) {
            if isManual || profile == nil {
                ownTargets(canCountInstead: profile != nil)
            } else if let profile, let result = store.computedTargets {
                computed(profile: profile, targets: result.targets)
            }
        }
        .onChange(of: memory.ownTargets) { _, _ in
            saveOwnTargets()
        }
    }

    private var isManualSetting: Bool {
        if case .manual = store.data.targetsSetting {
            return true
        }
        return false
    }

    private func subtitle(hasProfile: Bool, isManual: Bool) -> String {
        if isManual {
            return "Twoje własne liczby – zapisuję je od razu"
        }
        return hasProfile
            ? "policzyłam je z liczb, które mi podałaś"
            : "bez liczb o Tobie nie policzę ich sama – możesz wpisać własne"
    }

    // MARK: - Counted from her numbers

    private func computed(profile: NutritionProfile, targets: Macros) -> some View {
        VStack(alignment: .leading, spacing: Spacing.group) {
            WelcomeTargetsCard(targets: targets)
            VStack(alignment: .leading, spacing: Spacing.item) {
                SectionHeader("ile się ruszasz?", subtitle: "w zwykłym tygodniu")
                ChoiceTiles(options: ActivityLevel.allCases, selection: profile.activity, columns: 2,
                            label: { Self.activityLabel($0) },
                            onSelect: { setActivity($0) })
            }
            paceChoice(WelcomePace.closest(to: profile.deficitKcal))
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Button("wolę wpisać własne", action: useOwnTargets)
                    .buttonStyle(LinkButtonStyle())
                MoreInfo("jak to liczę?",
                         text: "biorę Twój wiek, wzrost, wagę i to, ile się ruszasz, a potem odejmuję trochę – w tempie, które wybierzesz. To szacunek: w „jedzeniu” zmienisz go w każdej chwili")
            }
        }
    }

    /// The pace stays folded – the gentle one suits most days – and opens on a tap.
    private func paceChoice(_ pace: WelcomePace) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    showsPace.toggle()
                }
            } label: {
                HStack(spacing: Spacing.item) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("tempo")
                            .rowTitle()
                        Text(pace.label)
                            .rowDetail()
                    }
                    Spacer(minLength: Spacing.tight)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                        .rotationEffect(.degrees(showsPace ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: TapSize.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(showsPace ? "rozwinięte" : "zwinięte"))
            if showsPace {
                ChoiceTiles(options: WelcomePace.allCases, selection: pace, columns: 1,
                            label: { $0.label },
                            onSelect: { setPace($0) })
                    .transition(.opacity)
            }
        }
    }

    /// Short words for the tiles; the header says "w zwykłym tygodniu".
    private static func activityLabel(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: "mało ruchu"
        case .light: "1–3 treningi"
        case .moderate: "3–5 treningów"
        case .high: "6–7 treningów"
        }
    }

    private func setActivity(_ level: ActivityLevel) {
        guard var profile = store.data.nutritionProfile, profile.activity != level else { return }
        profile.activity = level
        withAnimation(.snappy(duration: 0.3)) {
            _ = store.saveNutrition(profile: profile, targets: store.data.targetsSetting)
        }
    }

    private func setPace(_ pace: WelcomePace) {
        guard var profile = store.data.nutritionProfile, profile.deficitKcal != pace.rawValue else { return }
        profile.deficitKcal = pace.rawValue
        withAnimation(.snappy(duration: 0.3)) {
            _ = store.saveNutrition(profile: profile, targets: store.data.targetsSetting)
        }
    }

    /// "wolę wpisać własne": her own numbers from now on, starting from the counted ones.
    private func useOwnTargets() {
        guard let suggestion = store.computedTargets?.targets else { return }
        let draft = Self.draft(from: suggestion)
        memory.ownTargetsSaved = draft
        memory.ownTargets = draft
        memory.hasLoadedOwnTargets = true
        withAnimation(.smooth(duration: 0.25)) {
            _ = store.saveNutrition(profile: nil, targets: .manual(suggestion))
        }
    }

    /// "policz je za mnie": back to targets counted from her numbers.
    private func useCountedTargets() {
        focus = nil
        withAnimation(.smooth(duration: 0.25)) {
            _ = store.saveNutrition(profile: nil, targets: .automatic)
        }
    }

    // MARK: - Her own numbers

    private func ownTargets(canCountInstead: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            Card {
                VStack(spacing: 0) {
                    WelcomeNumberRow("kalorie", unit: "kcal", onTap: { focus = .kcal }) {
                        targetField("1600", text: $memory.ownTargets.kcal, field: .kcal, label: "kalorie na dzień")
                    }
                    RowDivider()
                    WelcomeNumberRow("białko", unit: "g", onTap: { focus = .protein }) {
                        targetField("100", text: $memory.ownTargets.protein, field: .protein, label: "białko w gramach")
                    }
                    RowDivider()
                    WelcomeNumberRow("węglowodany", unit: "g", onTap: { focus = .carbs }) {
                        targetField("180", text: $memory.ownTargets.carbs, field: .carbs, label: "węglowodany w gramach")
                    }
                    RowDivider()
                    WelcomeNumberRow("tłuszcz", unit: "g", onTap: { focus = .fat }) {
                        targetField("55", text: $memory.ownTargets.fat, field: .fat, label: "tłuszcz w gramach")
                    }
                }
            }
            ownStatus
            if canCountInstead {
                Button("policz je za mnie", action: useCountedTargets)
                    .buttonStyle(LinkButtonStyle())
            }
        }
        .onAppear(perform: loadOwnTargets)
    }

    private func targetField(_ placeholder: String, text: Binding<String>, field: WelcomeTargetField,
                             label: String) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.title3.monospacedDigit())
            .foregroundStyle(Palette.text)
            .focused($focus, equals: field)
            .accessibilityLabel(Text(label))
    }

    /// One line under the fields: what still needs her, or that her numbers are saved.
    @ViewBuilder
    private var ownStatus: some View {
        let draft = memory.ownTargets
        if let problem = ownProblem(draft) {
            Text(polish: problem)
                .font(.footnote)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
        } else if let macros = BodyNumbers.ownTargets(kcal: draft.kcal, protein: draft.protein,
                                                      carbs: draft.carbs, fat: draft.fat) {
            if macros.kcal < TargetCalculator.minimumKcal {
                Text(polish: "to niewiele jak na cały dzień – zapisałam, ale bądź dla siebie łagodna")
                    .font(.footnote)
                    .foregroundStyle(Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ConfirmationNote(text: "zapisałam Twoje liczby")
            }
        } else if !draft.isEmpty {
            Text(polish: "zapiszę, gdy wpiszesz wszystkie cztery")
                .hintText()
        }
    }

    /// The first number that can't be right – not while she is still typing it.
    private func ownProblem(_ draft: WelcomeTargetsDraft) -> String? {
        if focus != .kcal, !Self.isBlank(draft.kcal), BodyNumbers.dailyKcal(draft.kcal) == nil {
            return "kalorie wpisz na cały dzień, od 800 do 4000"
        }
        let grams: [(WelcomeTargetField, String, String)] = [
            (.protein, draft.protein, "białko wpisz w gramach, np. 100"),
            (.carbs, draft.carbs, "węglowodany wpisz w gramach, np. 180"),
            (.fat, draft.fat, "tłuszcz wpisz w gramach, np. 55"),
        ]
        for (field, text, problem) in grams where focus != field && !Self.isBlank(text) && BodyNumbers.grams(text) == nil {
            return problem
        }
        return nil
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The fields as they show saved numbers ("1634", "12,5").
    private static func draft(from macros: Macros) -> WelcomeTargetsDraft {
        WelcomeTargetsDraft(kcal: BodyNumbers.text(macros.kcal),
                            protein: BodyNumbers.text(macros.protein),
                            carbs: BodyNumbers.text(macros.carbs),
                            fat: BodyNumbers.text(macros.fat))
    }

    /// Her saved own numbers, or empty fields; loading itself saves nothing.
    private func loadOwnTargets() {
        guard !memory.hasLoadedOwnTargets else { return }
        var draft = WelcomeTargetsDraft()
        if case .manual(let macros) = store.data.targetsSetting {
            draft = Self.draft(from: macros)
        }
        memory.ownTargetsSaved = draft
        memory.ownTargets = draft
        memory.hasLoadedOwnTargets = true
    }

    /// Saved once all four can be right; a change only to something that can't be right waits.
    private func saveOwnTargets() {
        let draft = memory.ownTargets
        guard memory.hasLoadedOwnTargets, draft != memory.ownTargetsSaved else { return }
        memory.ownTargetsSaved = draft
        guard let macros = BodyNumbers.ownTargets(kcal: draft.kcal, protein: draft.protein,
                                                  carbs: draft.carbs, fat: draft.fat),
              store.data.targetsSetting != .manual(macros)
        else { return }
        _ = store.saveNutrition(profile: nil, targets: .manual(macros))
    }

    // MARK: - Moving on

    private func text(of field: WelcomeTargetField) -> String {
        switch field {
        case .kcal: memory.ownTargets.kcal
        case .protein: memory.ownTargets.protein
        case .carbs: memory.ownTargets.carbs
        case .fat: memory.ownTargets.fat
        }
    }

    /// "dalej" first goes to the next empty field; then on.
    private func moveOn() {
        let order: [WelcomeTargetField] = [.kcal, .protein, .carbs, .fat]
        if let current = focus, let index = order.firstIndex(of: current),
           let empty = order[(index + 1)...].first(where: { Self.isBlank(text(of: $0)) }) {
            focus = empty
            return
        }
        focus = nil
        onNext()
    }

    private func skip() {
        focus = nil
        onNext()
    }
}

/// The counted targets: the kcal large, protein, carbohydrates and fat in one line under them.
private struct WelcomeTargetsCard: View {
    let targets: Macros

    var body: some View {
        Card(style: .highlight) {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                    Text(verbatim: "\(BodyNumbers.whole(targets.kcal))")
                        .bigNumber()
                        .contentTransition(.numericText())
                    Text("kcal na dzień")
                        .rowDetail()
                }
                Text(verbatim: "białko \(BodyNumbers.whole(targets.protein)) g · węglowodany \(BodyNumbers.whole(targets.carbs)) g · tłuszcz \(BodyNumbers.whole(targets.fat)) g")
                    .bodyText()
            }
        }
        .accessibilityElement(children: .combine)
    }
}
