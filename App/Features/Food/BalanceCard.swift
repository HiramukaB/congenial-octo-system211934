import SwiftUI
import AboutHerCore

/// "bilans dnia": what she ate on the day against her daily targets. The kcal lead – one big
/// number and one bar – then protein with its own bar, carbohydrates and fat in one quiet line,
/// and at most one short note. The movement she logged that day adds to the kcal target.
struct BalanceCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate
    let onEditTargets: () -> Void

    var body: some View {
        let eaten = store.data.eaten(on: day)
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("bilans dnia") {
                    Button(action: onEditTargets) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body)
                            .foregroundStyle(Palette.accent)
                            .frame(width: TapSize.minimum, height: TapSize.minimum)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Twoje cele dzienne")
                }
                if let targets = store.targetsWithMovement(on: day) {
                    kcalBlock(eaten: eaten.kcal, target: targets.kcal)
                    VStack(alignment: .leading, spacing: Spacing.item) {
                        MacroRow(label: "białko", eaten: eaten.protein, target: targets.protein, unit: " g")
                        otherMacros(eaten: eaten, targets: targets)
                    }
                    if let note = note(eaten: eaten, targets: targets) {
                        Text(polish: note)
                            .hintText()
                    }
                } else {
                    withoutTargets(eaten: eaten)
                }
            }
        }
    }

    // MARK: - Parts

    /// "1075 z 1748 kcal" and its bar.
    private func kcalBlock(eaten: Double, target: Double) -> some View {
        let eatenKcal = FoodFormat.whole(eaten)
        let targetKcal = FoodFormat.whole(target)
        return VStack(alignment: .leading, spacing: Spacing.item) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                Text(verbatim: "\(eatenKcal)")
                    .displayFont(40, relativeTo: .largeTitle)
                    .foregroundStyle(Palette.text)
                    .contentTransition(.numericText(value: Double(eatenKcal)))
                Text(verbatim: "z \(targetKcal) kcal")
                    .font(.body)
                    .foregroundStyle(Palette.text2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "kalorie: \(eatenKcal) z \(targetKcal) kcal"))
            FoodBar(fraction: target > 0 ? eaten / target : 0, height: 10)
        }
    }

    /// "węglowodany 152 z 174 g · tłuszcz 28 z 52 g": smaller than protein, without bars.
    private func otherMacros(eaten: Macros, targets: Macros) -> some View {
        let carbs = "węglowodany \(FoodFormat.whole(eaten.carbs)) z \(FoodFormat.whole(targets.carbs)) g"
        let fat = "tłuszcz \(FoodFormat.whole(eaten.fat)) z \(FoodFormat.whole(targets.fat)) g"
        return Text(verbatim: "\(carbs) · \(fat)")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(Palette.text2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(verbatim: "\(carbs), \(fat)"))
    }

    /// No targets yet: what she ate, if anything, and the way to her targets.
    @ViewBuilder
    private func withoutTargets(eaten: Macros) -> some View {
        if eaten.kcal > 0 {
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                    Text(verbatim: "\(FoodFormat.whole(eaten.kcal))")
                        .displayFont(40, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.text)
                    Text("kcal")
                        .font(.body)
                        .foregroundStyle(Palette.text2)
                }
                Text(verbatim: "białko \(FoodFormat.whole(eaten.protein)) g · węglowodany \(FoodFormat.whole(eaten.carbs)) g · tłuszcz \(FoodFormat.whole(eaten.fat)) g")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        Text(polish: "policzę Twoje cele, gdy powiesz mi coś o sobie")
            .bodyText()
        StarActionButton("ustal cele", size: .regular, action: onEditTargets)
    }

    // MARK: - The one line

    /// Today, once she has eaten: what is left, gently. Otherwise only what movement added, if it did.
    private func note(eaten: Macros, targets: Macros) -> String? {
        let movement = FoodFormat.whole(store.movementKcal(on: day).rounded())
        if day == store.today && !store.data.meals(on: day).isEmpty {
            let left = targets.kcal - eaten.kcal
            guard left >= 0 else {
                return "dziś trochę ponad cel – to nic, liczy się cały tydzień"
            }
            let leftText = "zostało Ci \(FoodFormat.whole(left)) kcal"
            return movement >= 1 ? "\(leftText), w tym \(movement) za ruch" : leftText
        }
        return movement >= 1 ? "ruch dodał do celu \(movement) kcal" : nil
    }
}

/// One line of the balance: label, "51 z 117 g" and a gentle bar that never turns red.
struct MacroRow: View {
    let label: String
    let eaten: Double
    let target: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tight) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                Spacer(minLength: Spacing.tight)
                Text(verbatim: "\(FoodFormat.whole(eaten)) z \(FoodFormat.whole(target))\(unit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Palette.text)
            }
            FoodBar(fraction: target > 0 ? eaten / target : 0, height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(label): \(FoodFormat.whole(eaten)) z \(FoodFormat.whole(target))\(unit)"))
    }
}

/// A soft capsule filled up to `fraction` (0–1) in the accent – full when over, never another colour.
private struct FoodBar: View {
    let fraction: Double
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.line)
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: proxy.size.width * filled)
            }
        }
        .frame(height: height)
        .animation(.smooth, value: filled)
        .accessibilityHidden(true)
    }

    private var filled: CGFloat {
        guard fraction.isFinite else { return 0 }
        return CGFloat(Swift.min(1, Swift.max(0, fraction)))
    }
}
