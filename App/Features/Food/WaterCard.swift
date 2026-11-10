import SwiftUI
import AboutHerCore

/// Water in three parts of the day. Her own design: the smaller star takes a glass away,
/// the bigger accent star adds one, and the small star fades when there is nothing to take.
struct WaterCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate

    var body: some View {
        let waterDay = store.data.water(on: day)
        let goal = WaterDay.goalGlasses
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).sectionTitle()
                    Spacer()
                    Text("\(waterDay.total) / \(goal) szklanek")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.text2)
                        // VoiceOver would read the slash; "3 z 8 szklanek" is how it is said.
                        .accessibilityLabel(Text(verbatim: "\(waterDay.total) z \(goal) szklanek"))
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule()
                            .fill(Palette.accent)
                            .frame(width: proxy.size.width * CGFloat(Swift.min(1, Double(waterDay.total) / Double(goal))))
                    }
                }
                .frame(height: 6)
                .animation(.smooth, value: waterDay.total)
                .accessibilityHidden(true)
                ForEach(WaterDay.Slot.allCases, id: \.self) { slot in
                    WaterSlotRow(slot: slot, count: waterDay.count(in: slot),
                                 onAdd: { store.addWater(1, to: slot, on: day) },
                                 onRemove: { store.addWater(-1, to: slot, on: day) })
                }
                Text(polish: "orientacyjnie ok. 8 szklanek dziennie, rozłożonych równomiernie i mniej wieczorem, żeby nie budzić się w nocy. To wskazówka, nie norma do odhaczenia – liczy się regularność, nie perfekcja")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Names the day whenever it isn't today, as the meal card does, so a glass never lands on
    /// another day unnoticed.
    private var title: String {
        day == store.today ? "woda" : "woda · \(PolishDate.dayMonth(day))"
    }
}

struct WaterSlotRow: View {
    let slot: WaterDay.Slot
    let count: Int
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(slot.label)
                    .font(.subheadline)
                    .foregroundStyle(Palette.text2)
                Text(slot.hours)
                    .font(.caption2)
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(PolishPlural.glasses(count))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Palette.text)
                .contentTransition(.numericText())
                .animation(.smooth, value: count)
            StarButton(label: "odejmij szklankę, \(slot.label)", size: 11, isEnabled: count > 0, action: onRemove)
            StarButton(label: "dodaj szklankę, \(slot.label)", size: 21, prominent: true, action: onAdd)
        }
    }
}
