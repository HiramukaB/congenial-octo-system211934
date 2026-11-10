import SwiftUI
import AboutHerCore

/// The day in short – what she ate and drank – as one card she can tap to open "jedzenie" on
/// that very day.
struct DaySummaryCard: View {
    let eaten: Macros
    let targets: Macros?
    let glasses: Int
    /// Today an empty day says "jeszcze nic"; earlier days show their numbers.
    var isToday = true
    let onOpenFood: () -> Void

    var body: some View {
        Button(action: onOpenFood) {
            Card {
                HStack(alignment: .center, spacing: Spacing.item) {
                    VStack(alignment: .leading, spacing: Spacing.tight) {
                        line("jedzenie", value: kcalText(joinedBy: " / "))
                        line("woda", value: waterText(joinedBy: " / "))
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(TilePressStyle())
        // VoiceOver hears "1075 z 1748 kcal" instead of a slash.
        .accessibilityLabel(Text(verbatim: "jedzenie: \(kcalText(joinedBy: " z ")), woda: \(waterText(joinedBy: " z "))"))
        .accessibilityHint(Text("otwiera jedzenie"))
    }

    private func line(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
            Text(label)
                .font(.body)
                .foregroundStyle(Palette.text2)
            Spacer(minLength: Spacing.tight)
            Text(value)
                .valueText()
                .multilineTextAlignment(.trailing)
        }
    }

    /// "1075 / 1748 kcal", "1075 kcal" without targets, "jeszcze nic" on an empty today.
    private func kcalText(joinedBy separator: String) -> String {
        let eatenKcal = Self.whole(eaten.kcal)
        if isToday && eatenKcal == 0 {
            return "jeszcze nic"
        }
        guard let targets else { return "\(eatenKcal) kcal" }
        return "\(eatenKcal)\(separator)\(Self.whole(targets.kcal)) kcal"
    }

    /// "4 / 8 szklanek", "jeszcze nic" on an empty today.
    private func waterText(joinedBy separator: String) -> String {
        if isToday && glasses == 0 {
            return "jeszcze nic"
        }
        return "\(glasses)\(separator)\(WaterDay.goalGlasses) szklanek"
    }

    /// A whole number that never traps, whatever the value.
    private static func whole(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(Swift.min(Swift.max(value, -1_000_000_000), 1_000_000_000).rounded())
    }
}

/// What may serve her in this phase: one line about her energy, and food, movement and the plan
/// of the day on tap – suggestions, never rules.
struct PhaseGuideCard: View {
    let phase: CyclePhase
    @State private var isOpen = false

    var body: some View {
        Card(style: .quiet) {
            VStack(alignment: .leading, spacing: Spacing.item) {
                HStack(alignment: .center, spacing: Spacing.tight) {
                    OrganicStar()
                        .fill(phase.tint)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    Text(verbatim: "\(phase.season) · co Ci posłuży")
                        .sectionTitle()
                        .accessibilityAddTraits(.isHeader)
                }
                Text(polish: phase.energyHint)
                    .bodyText()
                if isOpen {
                    VStack(alignment: .leading, spacing: Spacing.item) {
                        GuideRow(symbol: "fork.knife", title: "jedzenie", text: phase.foodHint)
                        GuideRow(symbol: "figure.yoga", title: "ruch", text: phase.movementHint)
                        GuideRow(symbol: "calendar", title: "plan dnia", text: phase.planningHint)
                        Text(polish: "to wskazówki, nie zasady. Jeśli dziś czujesz inaczej, słuchaj siebie")
                            .hintText()
                    }
                    .transition(.opacity)
                }
                TodayDetailsLink(isOpen: $isOpen, closedLabel: "jedzenie, ruch i plan dnia")
            }
        }
    }
}

struct GuideRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.item) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(Palette.accentDim)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.hairline) {
                Text(title)
                    .rowDetail()
                Text(polish: text)
                    .bodyText()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The motto from the web version, as a quiet line at the end of "dziś".
struct QuoteLine: View {
    var body: some View {
        Text("od wielkiego marzenia dzielą Cię małe codzienne decyzje")
            .font(.ahDisplay(13).italic())
            .foregroundStyle(Palette.accentDim)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Spacing.tight)
    }
}

/// "jedzenie, ruch i plan dnia ⌄" / "mniej ⌃": opens and closes details in place, in the look of
/// `MoreInfo`, for details that are more than one hint.
private struct TodayDetailsLink: View {
    @Binding var isOpen: Bool
    let closedLabel: String

    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) {
                isOpen.toggle()
            }
        } label: {
            HStack(spacing: Spacing.hairline) {
                Text(isOpen ? "mniej" : closedLabel)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
        .accessibilityValue(Text(isOpen ? "rozwinięte" : "zwinięte"))
    }
}
