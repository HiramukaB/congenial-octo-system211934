import SwiftUI
import AboutHerCore

/// "Twoje cele dzienne": a few facts about her, and the targets computed from them
/// (or her own numbers, if she prefers). Nothing personal is pre-filled from code.
struct NutritionProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var birthYear = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var activity: ActivityLevel = .light
    @State private var pace: Pace = .gentle
    @State private var usesOwnTargets = false
    @State private var ownKcal = ""
    @State private var ownProtein = ""
    @State private var ownCarbs = ""
    @State private var ownFat = ""
    @State private var didLoad = false

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    numberField("rok urodzenia", text: $birthYear, placeholder: "np. 1995")
                    numberField("wzrost (cm)", text: $height, placeholder: "np. 165")
                    numberField("waga (kg)", text: $weight, placeholder: "np. 64,5")
                    Picker("aktywność", selection: $activity) {
                        ForEach(ActivityLevel.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    Picker("tempo", selection: $pace) {
                        ForEach(Pace.allCases) { pace in
                            Text(pace.label).tag(pace)
                        }
                    }
                } header: {
                    Text("o Tobie")
                } footer: {
                    Text(polish: "mogę policzyć cele za Ciebie. Gdy zaczniesz się ważyć, sama uwzględnię linię trendu wagi")
                }

                if let result = preview {
                    Section {
                        LabeledContent("przemiana materii", value: "\(FoodFormat.whole(result.bmr)) kcal")
                        LabeledContent("zapotrzebowanie", value: "\(FoodFormat.whole(result.tdee)) kcal")
                        LabeledContent("cel", value: "\(FoodFormat.whole(result.targets.kcal)) kcal")
                        LabeledContent("białko", value: "\(FoodFormat.whole(result.targets.protein)) g")
                        LabeledContent("węglowodany", value: "\(FoodFormat.whole(result.targets.carbs)) g")
                        LabeledContent("tłuszcz", value: "\(FoodFormat.whole(result.targets.fat)) g")
                    } header: {
                        Text("tak to liczę")
                    } footer: {
                        Text(polish: notes(for: result))
                    }
                }

                Section {
                    Toggle("wolę wpisać własne cele", isOn: $usesOwnTargets)
                    if usesOwnTargets {
                        numberField("kcal", text: $ownKcal, placeholder: "kcal")
                        numberField("białko (g)", text: $ownProtein, placeholder: "g")
                        numberField("węglowodany (g)", text: $ownCarbs, placeholder: "g")
                        numberField("tłuszcz (g)", text: $ownFat, placeholder: "g")
                    }
                } footer: {
                    Text(polish: "to szacunek, nie zalecenie medyczne – nie zastępuje rozmowy z lekarzem ani dietetyczką")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Twoje cele dzienne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("zapisz", action: save)
                        .disabled(profile == nil || (usesOwnTargets && ownTargets == nil))
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.large])
    }

    private func numberField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        LabeledContent(label) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Values

    private var profile: NutritionProfile? {
        guard let year = Int(birthYear.trimmingCharacters(in: .whitespaces)),
              (1920...store.today.year - 10).contains(year),
              let heightCm = FoodFormat.parseNumber(height), (120...220).contains(heightCm),
              let weightKg = FoodFormat.parseNumber(weight), (25...250).contains(weightKg)
        else { return nil }
        return NutritionProfile(birthYear: year, heightCm: heightCm, weightKg: weightKg,
                                activity: activity, deficitKcal: pace.rawValue)
    }

    private var preview: TargetResult? {
        guard let profile else { return nil }
        return TargetCalculator.compute(profile: profile, weightKg: nil, year: store.today.year)
    }

    private var ownTargets: Macros? {
        guard let kcal = FoodFormat.parseNumber(ownKcal), kcal > 0,
              let protein = FoodFormat.parseNumber(ownProtein),
              let carbs = FoodFormat.parseNumber(ownCarbs),
              let fat = FoodFormat.parseNumber(ownFat)
        else { return nil }
        return Macros(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    private func notes(for result: TargetResult) -> String {
        var lines: [String] = []
        if result.adjustments.contains(.deficitLimited) {
            lines.append("deficyt ograniczyłam do 20% zapotrzebowania – tak jest łagodniej dla ciała")
        }
        if result.adjustments.contains(.raisedToMinimum) {
            lines.append("nie schodzę poniżej bezpiecznego minimum, więc cel jest trochę wyższy")
        }
        if result.adjustments.contains(.proteinLowered) || result.adjustments.contains(.fatLowered) {
            lines.append("zostawiłam więcej miejsca na węglowodany, żeby starczyło Ci energii")
        }
        if lines.isEmpty {
            lines.append("przemiana materii według wzoru Mifflina–St Jeora, białko 1,8 g na kilogram masy ciała")
        }
        return lines.joined(separator: ". ")
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let saved = store.data.nutritionProfile {
            birthYear = String(saved.birthYear)
            height = FoodFormat.number(saved.heightCm, decimals: 0)
            activity = saved.activity
            pace = Pace.allCases.min(by: { abs($0.rawValue - saved.deficitKcal) < abs($1.rawValue - saved.deficitKcal) }) ?? .gentle
        }
        if let current = store.currentWeight {
            weight = FoodFormat.number(current)
        }
        if case .manual(let macros) = store.data.targetsSetting {
            usesOwnTargets = true
            ownKcal = String(FoodFormat.whole(macros.kcal))
            ownProtein = String(FoodFormat.whole(macros.protein))
            ownCarbs = String(FoodFormat.whole(macros.carbs))
            ownFat = String(FoodFormat.whole(macros.fat))
        }
    }

    private func save() {
        guard let profile else { return }
        if usesOwnTargets {
            guard let ownTargets else { return }
            store.saveNutrition(profile: profile, targets: .manual(ownTargets))
        } else {
            store.saveNutrition(profile: profile, targets: .automatic)
        }
        dismiss()
    }
}
