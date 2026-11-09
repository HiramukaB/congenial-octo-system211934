import SwiftUI
import AboutHerCore

/// "bilans dnia": what she ate on the day against her daily targets.
struct BalanceCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate
    let onEditTargets: () -> Void

    var body: some View {
        let eaten = store.data.eaten(on: day)
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("bilans dnia").sectionTitle()
                    Spacer()
                    Button(action: onEditTargets) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.subheadline)
                            .foregroundStyle(Palette.accentDim)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Twoje cele dzienne")
                }
                if let targets = store.targets {
                    MacroRow(label: "kcal", eaten: eaten.kcal, target: targets.kcal, unit: "")
                    MacroRow(label: "białko", eaten: eaten.protein, target: targets.protein, unit: " g")
                    MacroRow(label: "węglowodany", eaten: eaten.carbs, target: targets.carbs, unit: " g")
                    MacroRow(label: "tłuszcz", eaten: eaten.fat, target: targets.fat, unit: " g")
                    Text(polish: summary(eaten: eaten, targets: targets))
                        .font(.footnote)
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    if eaten.kcal > 0 {
                        Text(FoodFormat.macrosLine(eaten))
                            .font(.subheadline)
                            .foregroundStyle(Palette.text2)
                    }
                    Text(polish: "żeby policzyć Twoje cele, potrzebuję kilku informacji o Tobie: wzrostu, wagi, roku urodzenia i aktywności")
                        .bodyText()
                    Button("uzupełnij", action: onEditTargets)
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func summary(eaten: Macros, targets: Macros) -> String {
        let left = (targets - eaten)
        if eaten.kcal <= 0 {
            return "tu zobaczysz, ile zostało Ci do celu, gdy zapiszesz pierwszy posiłek"
        }
        if left.kcal >= 0 {
            let protein = FoodFormat.whole(Swift.max(0, left.protein))
            return "do celu zostało Ci \(FoodFormat.whole(left.kcal)) kcal i \(protein) g białka"
        }
        return "dziś trochę ponad cel – to nic, liczy się cały tydzień, nie jeden dzień"
    }
}

/// One line of the balance: label, "45 / 110 g" and a gentle bar that never turns red.
struct MacroRow: View {
    let label: String
    let eaten: Double
    let target: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                Spacer()
                Text("\(FoodFormat.whole(eaten)) / \(FoodFormat.whole(target))\(unit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Palette.text)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 6)
            .animation(.smooth, value: fraction)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label): \(FoodFormat.whole(eaten)) z \(FoodFormat.whole(target))\(unit)"))
    }

    private var fraction: CGFloat {
        guard target > 0 else { return 0 }
        return CGFloat(Swift.min(1, Swift.max(0, eaten / target)))
    }
}
