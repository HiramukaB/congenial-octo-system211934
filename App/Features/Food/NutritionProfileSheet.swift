import SwiftUI
import UIKit
import Combine
import AboutHerCore

/// "Twoje cele dzienne": a few facts about her, and the targets computed from them
/// (or her own numbers, if she prefers). Nothing personal is pre-filled from code.
///
/// The sheet saves itself when it closes (a swipe down) and when the app goes to the background,
/// but only when something changed and what she typed can be used. While a change can't be saved
/// yet, the sheet stays open, a gentle line names the first field that needs her, and "zamknij bez
/// zmian" at the top leaves everything as it was saved.
struct NutritionProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Draft()
    /// The form as it opened, or as it was last saved; nil until it has been filled from her saved data.
    @State private var initial: Draft? = nil
    @State private var isCancelled = false

    enum Pace: Double, CaseIterable, Identifiable {
        case maintain = 0
        case gentle = 250
        case moderate = 400

        var id: Double { rawValue }

        var label: String {
            switch self {
            case .maintain: "utrzymanie wagi"
            case .gentle: "łagodnie, ok. −250 kcal"
            case .moderate: "umiarkowanie, ok. −400 kcal"
            }
        }
    }

    /// Everything she can type, as text, exactly as in the fields.
    private struct Draft: Equatable {
        var birthYear = ""
        var height = ""
        var weight = ""
        var activity: ActivityLevel = .light
        var pace: Pace = .gentle
        var usesOwnTargets = false
        var ownKcal = ""
        var ownProtein = ""
        var ownCarbs = ""
        var ownFat = ""
    }

    /// A field that needs her: nothing typed yet, or a value that can't be right. Worded as
    /// guidance, so it also reads well while she is still typing.
    private struct Problem {
        let text: String
        let isMissing: Bool

        static func missing(_ text: String) -> Problem {
            Problem(text: text, isMissing: true)
        }

        static func wrong(_ text: String) -> Problem {
            Problem(text: text, isMissing: false)
        }
    }

    /// One value of the form: usable, or what still needs her.
    private enum Check<Value> {
        case valid(Value)
        case needs(Problem)

        var value: Value? {
            if case .valid(let value) = self {
                return value
            }
            return nil
        }

        var problem: Problem? {
            if case .needs(let problem) = self {
                return problem
            }
            return nil
        }
    }

    var body: some View {
        FoodSheetPage {
            ScreenHeader(title: "Twoje cele dzienne", subtitle: "zapisuję sama, gdy zamkniesz")
            if isBlocked {
                FoodUnsavedNote {
                    isCancelled = true
                    dismiss()
                }
            }
            aboutCard
            if let result = preview {
                resultCard(result)
            }
            ToggleTile(title: "wolę wpisać własne cele", isOn: draft.usesOwnTargets) {
                withAnimation(.snappy(duration: 0.2)) {
                    draft.usesOwnTargets.toggle()
                }
            }
            if draft.usesOwnTargets {
                ownTargetsCard
            }
            Text(polish: "to szacunek, nie zalecenie medyczne – nie zastępuje rozmowy z lekarzem ani dietetyczką")
                .hintText()
        }
        // A change that can't be saved yet keeps the sheet open, so nothing she typed is lost
        // by a swipe; "zamknij bez zmian" still closes it.
        .interactiveDismissDisabled(isBlocked)
        .onAppear(perform: load)
        .onDisappear {
            if !isCancelled {
                commit()
            }
        }
        // In the background the app may be ended before the sheet ever closes: what can be used is
        // saved and written now, and from then on only a later change is saved again.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            guard !isCancelled else { return }
            let saved = commit()
            store.saveNow()
            if saved {
                initial = draft
            }
        }
    }

    // MARK: - Cards

    private var aboutCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("o Tobie")
                VStack(spacing: Spacing.tight) {
                    FoodNumberRow("rok urodzenia", text: $draft.birthYear, placeholder: "np. 1995",
                                  keyboard: .numberPad)
                    FoodNumberRow("wzrost", text: $draft.height, placeholder: "np. 165", unit: "cm")
                    if let trendWeight {
                        // Her weigh-ins decide the weight the targets use; a new one belongs in "waga".
                        ListRow("waga", detail: "z linii trendu wagi") {
                            Text(verbatim: "\(FoodFormat.number(trendWeight)) kg")
                                .valueText()
                        }
                    } else {
                        FoodNumberRow("waga", text: $draft.weight, placeholder: "np. 64,5", unit: "kg")
                    }
                }
                choices("aktywność") {
                    ChoiceTiles(options: ActivityLevel.allCases,
                                selection: draft.activity,
                                columns: 2,
                                label: { Self.activityTitle($0) },
                                onSelect: { draft.activity = $0 })
                }
                choices("tempo") {
                    ChoiceTiles(options: Pace.allCases,
                                selection: draft.pace,
                                columns: 1,
                                label: { $0.label },
                                onSelect: { draft.pace = $0 })
                }
                if let profileHint {
                    Text(polish: profileHint)
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// What I'd set: the kcal big, the three macros under them, how I count it on tap.
    private func resultCard(_ result: TargetResult) -> some View {
        // With her own numbers on, this is only what the app would suggest, so it steps back.
        Card(style: draft.usesOwnTargets ? CardStyle.quiet : CardStyle.highlight) {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader(draft.usesOwnTargets ? "tak bym to policzyła" : "tak to liczę")
                HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                    Text(verbatim: "\(FoodFormat.whole(result.targets.kcal))")
                        .displayFont(40, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.text)
                    Text("kcal dziennie")
                        .font(.body)
                        .foregroundStyle(Palette.text2)
                }
                .accessibilityElement(children: .combine)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Spacing.item) {
                        targetStats(result.targets)
                    }
                    VStack(alignment: .leading, spacing: Spacing.item) {
                        targetStats(result.targets)
                    }
                }
                MoreInfo("jak to liczę?", text: notes(for: result))
            }
        }
    }

    private var ownTargetsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                VStack(spacing: Spacing.tight) {
                    FoodNumberRow("kcal", text: $draft.ownKcal, placeholder: "np. 1600", unit: "kcal")
                    FoodNumberRow("białko", text: $draft.ownProtein, placeholder: "np. 100", unit: "g")
                    FoodNumberRow("węglowodany", text: $draft.ownCarbs, placeholder: "np. 180", unit: "g")
                    FoodNumberRow("tłuszcz", text: $draft.ownFat, placeholder: "np. 55", unit: "g")
                }
                ForEach(ownTargetNotes, id: \.self) { note in
                    Text(polish: note)
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - Parts

    /// A group of tiles with its short name above it.
    private func choices<Tiles: View>(_ title: String, @ViewBuilder tiles: () -> Tiles) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Palette.text2)
            tiles()
        }
    }

    @ViewBuilder
    private func targetStats(_ targets: Macros) -> some View {
        targetStat("białko", grams: targets.protein)
        targetStat("węglowodany", grams: targets.carbs)
        targetStat("tłuszcz", grams: targets.fat)
    }

    private func targetStat(_ label: String, grams: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "\(FoodFormat.whole(grams)) g")
                .valueText()
            Text(label)
                .rowDetail()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Shorter words than `ActivityLevel.label`, so two tiles fit side by side.
    private static func activityTitle(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: "bez treningów"
        case .light: "1–3 treningi w tygodniu"
        case .moderate: "3–5 treningów w tygodniu"
        case .high: "6–7 treningów w tygodniu"
        }
    }

    // MARK: - Values

    /// Once she has weigh-ins, the weight her targets use: the trend line, as in the balance.
    private var trendWeight: Double? {
        WeightTrend.trend(on: store.today, in: store.weightPoints)
    }

    private var birthYearCheck: Check<Int> {
        let text = draft.birthYear.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return .needs(.missing("jeszcze potrzebuję roku urodzenia, np. 1995"))
        }
        guard let year = Int(text), year >= 1920, year <= store.today.year - 10 else {
            return .needs(.wrong("rok urodzenia wpisz w całości, np. 1995"))
        }
        return .valid(year)
    }

    private var heightCheck: Check<Double> {
        let text = draft.height.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return .needs(.missing("jeszcze potrzebuję wzrostu w centymetrach, np. 165"))
        }
        guard var centimetres = FoodFormat.parseNumber(text) else {
            return .needs(.wrong("wzrost podaj w centymetrach, np. 165"))
        }
        if centimetres >= 1.2 && centimetres <= 2.2 {
            // "1,65" is in metres.
            centimetres = (centimetres * 1000).rounded() / 10
        }
        guard centimetres >= 120 && centimetres <= 220 else {
            return .needs(.wrong("wzrost podaj w centymetrach, np. 165"))
        }
        return .valid(centimetres)
    }

    private var weightCheck: Check<Double> {
        if let trendWeight {
            return .valid(trendWeight)
        }
        let text = draft.weight.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return .needs(.missing("jeszcze potrzebuję wagi w kilogramach, np. 64,5"))
        }
        guard let kilograms = FoodFormat.parseNumber(text), kilograms >= 25, kilograms <= 250 else {
            return .needs(.wrong("wagę podaj w kilogramach, np. 64,5"))
        }
        return .valid(kilograms)
    }

    private var profile: NutritionProfile? {
        guard let year = birthYearCheck.value,
              let heightCm = heightCheck.value,
              let weightKg = weightCheck.value
        else { return nil }
        return NutritionProfile(birthYear: year, heightCm: heightCm, weightKg: weightKg,
                                activity: draft.activity, deficitKcal: draft.pace.rawValue)
    }

    private var profileProblems: [Problem] {
        [birthYearCheck.problem, heightCheck.problem, weightCheck.problem].compactMap { $0 }
    }

    /// She has typed something about herself. With her own targets the profile is optional, but
    /// one she started is saved only complete, so nothing she typed is dropped without a word.
    private var profileIsStarted: Bool {
        let typed = trendWeight == nil
            ? [draft.birthYear, draft.height, draft.weight]
            : [draft.birthYear, draft.height]
        return typed.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// The first field of the profile that needs her. With her own targets and nothing typed
    /// about herself, only a value that can't be right is mentioned.
    private var profileHint: String? {
        let includesMissing = !draft.usesOwnTargets || profileIsStarted
        return profileProblems.first(where: { includesMissing || !$0.isMissing })?.text
    }

    private var preview: TargetResult? {
        guard let profile else { return nil }
        // With weigh-ins this is her trend weight, so the preview shows the targets the balance will use.
        return TargetCalculator.compute(profile: profile, weightKg: trendWeight, year: store.today.year)
    }

    private var ownTargetsCheck: Check<Macros> {
        let kcalText = draft.ownKcal.trimmingCharacters(in: .whitespaces)
        guard !kcalText.isEmpty else {
            return .needs(.missing("jeszcze potrzebuję dziennego celu kcal"))
        }
        guard let kcal = FoodFormat.parseNumber(kcalText) else {
            return .needs(.wrong("kcal wpisz jako liczbę, np. 1600"))
        }
        // Outside this range it is a typo, not a daily target, and is not saved.
        guard kcal >= 800, kcal <= 4000 else {
            return .needs(.wrong("wpisz cel na cały dzień, od 800 do 4000 kcal – inna liczba to raczej literówka"))
        }
        let gramFields = [
            (draft.ownProtein, "jeszcze potrzebuję celu białka w gramach", "białko wpisz w gramach, np. 100"),
            (draft.ownCarbs, "jeszcze potrzebuję celu węglowodanów w gramach", "węglowodany wpisz w gramach, np. 180"),
            (draft.ownFat, "jeszcze potrzebuję celu tłuszczu w gramach", "tłuszcz wpisz w gramach, np. 55"),
        ]
        var grams: [Double] = []
        for (text, missingText, wrongText) in gramFields {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                return .needs(.missing(missingText))
            }
            guard let value = FoodFormat.parseNumber(trimmed), value >= 0 else {
                return .needs(.wrong(wrongText))
            }
            grams.append(value)
        }
        return .valid(Macros(kcal: kcal, protein: grams[0], carbs: grams[1], fat: grams[2]))
    }

    /// What her own targets still need or – once they are complete – gentle notes that never
    /// stop her from saving them.
    private var ownTargetNotes: [String] {
        switch ownTargetsCheck {
        case .needs(let problem):
            return [problem.text]
        case .valid(let targets):
            var notes: [String] = []
            // The floor the automatic targets keep: 1200 kcal or her BMR, but never above her TDEE.
            let minimum = (preview.map { Swift.min(Swift.max(TargetCalculator.minimumKcal, $0.bmr), $0.tdee) }
                ?? TargetCalculator.minimumKcal).rounded()
            if targets.kcal < minimum {
                notes.append("to mniej niż minimum, poniżej którego sama nie schodzę (ok. \(FoodFormat.whole(minimum)) kcal). Zapiszę, ale może warto omówić to z dietetyczką")
            }
            let fromMacros = targets.kcalFromMacros
            if abs(fromMacros - targets.kcal) > 0.1 * targets.kcal {
                notes.append("z białka, węglowodanów i tłuszczu wychodzi ok. \(FoodFormat.whole(fromMacros)) kcal, a cel to \(FoodFormat.whole(targets.kcal)) kcal – może któraś liczba się pomyliła?")
            }
            return notes
        }
    }

    /// "jak to liczę?": the two numbers behind the target, the rules and what I adjusted.
    private func notes(for result: TargetResult) -> String {
        var lines: [String] = [
            "przemiana materii to ok. \(FoodFormat.whole(result.bmr)) kcal, a zapotrzebowanie ok. \(FoodFormat.whole(result.tdee)) kcal",
            trendWeight == nil
                ? "gdy zaczniesz się ważyć, sama uwzględnię linię trendu wagi"
                : "liczę z linii trendu wagi, więc cele same nadążają za zmianami",
            "przemianę materii liczę wzorem Mifflina–St Jeora",
            "białko to ok. 1,8 g na kilogram – liczę je od Twojej wagi, a najwyżej od wagi, która pasuje do Twojego wzrostu",
            "tłuszcz to co najmniej 25% energii, a resztę zostawiam na węglowodany – w miarę możliwości co najmniej 130 g",
        ]
        if result.adjustments.contains(.deficitLimited) {
            lines.append("deficyt ograniczyłam do 20% zapotrzebowania – tak jest łagodniej dla ciała")
        }
        if result.adjustments.contains(.raisedToMinimum) {
            lines.append("nie schodzę poniżej bezpiecznego minimum, więc cel jest trochę wyższy")
        }
        if result.adjustments.contains(.proteinLowered) || result.adjustments.contains(.fatLowered) {
            lines.append("zostawiłam trochę więcej miejsca na węglowodany, żeby starczyło Ci energii")
        }
        return Self.sentences(lines)
    }

    /// Joins short sentences: the first starts lowercase, like every note in the app, the rest
    /// with a capital letter.
    private static func sentences(_ lines: [String]) -> String {
        var result: [String] = []
        for line in lines {
            if result.isEmpty {
                result.append(line)
            } else {
                result.append(line.prefix(1).uppercased() + String(line.dropFirst()))
            }
        }
        return result.joined(separator: ". ")
    }

    // MARK: - Loading and saving

    private func load() {
        guard initial == nil else { return }
        var loaded = Draft()
        if let saved = store.data.nutritionProfile {
            loaded.birthYear = String(saved.birthYear)
            loaded.height = FoodFormat.compact(saved.heightCm)
            loaded.weight = FoodFormat.compact(saved.weightKg)
            loaded.activity = saved.activity
            loaded.pace = Pace.allCases.min(by: {
                abs($0.rawValue - saved.deficitKcal) < abs($1.rawValue - saved.deficitKcal)
            }) ?? .gentle
        }
        if case .manual(let macros) = store.data.targetsSetting {
            loaded.usesOwnTargets = true
            loaded.ownKcal = FoodFormat.compact(macros.kcal)
            loaded.ownProtein = FoodFormat.compact(macros.protein)
            loaded.ownCarbs = FoodFormat.compact(macros.carbs)
            loaded.ownFat = FoodFormat.compact(macros.fat)
        }
        draft = loaded
        initial = loaded
    }

    /// What would be saved: fields the current choices don't use are left out, so changing
    /// only them doesn't count as a change.
    private func essentials(_ form: Draft) -> Draft {
        var form = form
        if !form.usesOwnTargets {
            form.ownKcal = ""
            form.ownProtein = ""
            form.ownCarbs = ""
            form.ownFat = ""
        }
        if trendWeight != nil {
            form.weight = ""
        }
        return form
    }

    private var hasChanges: Bool {
        guard let initial else { return false }
        return essentials(draft) != essentials(initial)
    }

    /// Her own targets need no profile – but one she started must be complete; the computed
    /// targets always need it.
    private var canSave: Bool {
        if draft.usesOwnTargets {
            return ownTargetsCheck.value != nil && (profile != nil || !profileIsStarted)
        }
        return profile != nil
    }

    /// Something changed but can't be saved yet.
    private var isBlocked: Bool {
        hasChanges && !canSave
    }

    /// Opening and closing without a change writes nothing, so a read-only store raises no alert
    /// just because she looked. Returns `true` when the store saved it.
    @discardableResult
    private func commit() -> Bool {
        guard hasChanges, canSave else { return false }
        if draft.usesOwnTargets, let targets = ownTargetsCheck.value {
            // canSave lets this through without a complete profile only when nothing about her is
            // typed. The stored one goes only when the sheet showed it (its birth year is in
            // `initial`) and she emptied it: her file may be read only now, in canEdit, after the
            // sheet opened empty.
            let emptiedSavedProfile = !profileIsStarted && initial?.birthYear.isEmpty == false
            return store.saveNutrition(profile: profile, targets: .manual(targets), clearsProfile: emptiedSavedProfile)
        }
        if let profile {
            return store.saveNutrition(profile: profile, targets: .automatic)
        }
        return false
    }
}
