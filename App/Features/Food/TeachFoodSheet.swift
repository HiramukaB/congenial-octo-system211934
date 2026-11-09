import SwiftUI
import AboutHerCore

/// "nie znam jeszcze tego produktu": she gives the values once, and the app remembers them –
/// also for the meals already logged with it.
struct TeachFoodSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let suggestedName: String

    @State private var name = ""
    @State private var otherForms = ""
    @State private var basis: Basis = .portion
    @State private var portionUnit: PortionUnit = .serving
    @State private var portionGrams = "100"
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var didLoad = false

    enum Basis: Hashable {
        case portion, per100g
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("nazwa", text: $name)
                    TextField("inne formy, np. pierogów, pierogami", text: $otherForms)
                } footer: {
                    Text(polish: "podaj wartości raz, a zapamiętam je na przyszłość. Policzę je też w posiłkach, które już zapisałaś")
                }
                Section {
                    Picker("wartości podaję", selection: $basis) {
                        Text("na porcję").tag(Basis.portion)
                        Text("na 100 g").tag(Basis.per100g)
                    }
                    .pickerStyle(.segmented)
                    if basis == .portion {
                        Picker("porcja to", selection: $portionUnit) {
                            ForEach(PortionUnit.allCases, id: \.self) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        valueField("waga porcji (g)", text: $portionGrams)
                    }
                }
                Section {
                    valueField("kcal", text: $kcal)
                    valueField("białko (g)", text: $protein)
                    valueField("węglowodany (g)", text: $carbs)
                    valueField("tłuszcz (g)", text: $fat)
                } footer: {
                    Text(polish: "wartości znajdziesz na opakowaniu – zwykle na 100 g")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("nie znam jeszcze tego produktu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("anuluj") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("zapamiętaj", action: save)
                        .disabled(item == nil)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                name = suggestedName
            }
        }
        .presentationDetents([.large])
    }

    private func valueField(_ label: String, text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    /// The product as it will be saved; nil while something essential is missing.
    private var item: FoodItem? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanName.isEmpty, let kcalValue = FoodFormat.parseNumber(kcal), kcalValue >= 0 else { return nil }
        let grams = basis == .portion ? (FoodFormat.parseNumber(portionGrams) ?? 0) : 100
        guard grams > 0 else { return nil }
        let factor = 100 / grams
        let per100 = Macros(kcal: kcalValue,
                            protein: FoodFormat.parseNumber(protein) ?? 0,
                            carbs: FoodFormat.parseNumber(carbs) ?? 0,
                            fat: FoodFormat.parseNumber(fat) ?? 0).scaled(by: factor)
        var aliases = otherForms
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty && $0 != cleanName }
        // The words she actually typed, so the meal that started this is recognised too.
        let typed = suggestedName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !typed.isEmpty, typed != cleanName, !aliases.contains(typed) {
            aliases.append(typed)
        }
        let portion = Portion(unit: basis == .portion ? portionUnit : .serving, grams: grams)
        return FoodItem(id: "user-" + UUID().uuidString.lowercased(), name: cleanName, aliases: aliases,
                        category: .other, per100: per100, portions: [portion], defaultPortion: portion)
    }

    private func save() {
        guard let item else { return }
        store.teachFood(item)
        dismiss()
    }
}
