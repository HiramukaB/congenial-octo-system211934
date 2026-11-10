import SwiftUI
import AboutHerCore

/// "jak się dziś czujesz?": energy, mood, sleep, appetite and a few symptoms of one day, on "dziś"
/// and in the calendar's sheet. A tap marks a chip, a second tap takes it back, and every tap is
/// saved at once – there is nothing to confirm.
struct SymptomsCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate
    /// Counts the saved taps, for a light haptic on each.
    @State private var taps = 0

    var body: some View {
        let marked = store.data.symptoms(on: day)
        let flow = FlowLayout(spacing: 6, lineSpacing: 6)
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text(Self.title(on: day, today: store.today))
                    .sectionTitle()
                VStack(alignment: .leading, spacing: 8) {
                    SymptomRow<EnergyLevel>(
                        title: "energia", options: EnergyLevel.allCases,
                        label: { $0.label }, spoken: { "energia \($0.label)" },
                        isOn: { marked.energy == $0 }
                    ) { level in
                        saved(store.toggleSymptom(\.energy, level, on: day))
                    }
                    SymptomRow<MoodLevel>(
                        title: "nastrój", options: MoodLevel.allCases,
                        label: { $0.label }, spoken: { "nastrój \($0.label)" },
                        isOn: { marked.mood == $0 }
                    ) { level in
                        saved(store.toggleSymptom(\.mood, level, on: day))
                    }
                    SymptomRow<SleepQuality>(
                        title: "sen", options: SleepQuality.allCases,
                        label: { $0.label }, spoken: { "sen \($0.label)" },
                        isOn: { marked.sleep == $0 }
                    ) { quality in
                        saved(store.toggleSymptom(\.sleep, quality, on: day))
                    }
                    SymptomRow<AppetiteLevel>(
                        title: "apetyt", options: AppetiteLevel.allCases,
                        label: { $0.label }, spoken: { "apetyt \($0.label)" },
                        isOn: { marked.appetite == $0 }
                    ) { level in
                        saved(store.toggleSymptom(\.appetite, level, on: day))
                    }
                }
                flow {
                    ForEach(SymptomFlag.allCases, id: \.self) { flag in
                        SymptomChip(label: flag.label, spoken: flag.label, isOn: marked.flags.contains(flag)) {
                            saved(store.toggleSymptom(flag, on: day))
                        }
                    }
                }
                Text(polish: "zapisuję od razu – dotknij jeszcze raz, żeby odznaczyć")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sensoryFeedback(.selection, trigger: taps)
    }

    /// "jak się dziś czujesz?" for today; the days before in the past tense:
    /// "jak się czułaś wczoraj?", "jak się czułaś 7 listopada?".
    static func title(on day: LocalDate, today: LocalDate) -> String {
        if day == today {
            return "jak się dziś czujesz?"
        }
        if day == today.adding(days: -1) {
            return "jak się czułaś wczoraj?"
        }
        return "jak się czułaś \(PolishDate.dayMonth(day))?"
    }

    /// A refused tap (her data can't be changed right now) gets the store's alert instead of a haptic.
    private func saved(_ isSaved: Bool) {
        if isSaved {
            taps += 1
        }
    }
}

/// One scale: its name, then a chip for each of its values.
private struct SymptomRow<Option: Hashable>: View {
    let title: String
    let options: [Option]
    let label: (Option) -> String
    /// What VoiceOver says for a chip, with the scale's name: "energia niska".
    let spoken: (Option) -> String
    let isOn: (Option) -> Bool
    let onTap: (Option) -> Void
    /// Grows with the text size, so the longest name ("nastrój") keeps fitting.
    @ScaledMetric(relativeTo: .footnote) private var titleWidth: CGFloat = 58

    var body: some View {
        let flow = FlowLayout(spacing: 6, lineSpacing: 6)
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: titleWidth, alignment: .leading)
                // On one line with the words of the first chips.
                .padding(.top, SymptomChip.verticalPadding)
                // Every chip says it itself.
                .accessibilityHidden(true)
            flow {
                ForEach(options, id: \.self) { option in
                    SymptomChip(label: label(option), spoken: spoken(option), isOn: isOn(option)) {
                        onTap(option)
                    }
                }
            }
        }
    }
}

/// A soft capsule with a small star that lights up when it is marked.
private struct SymptomChip: View {
    /// The space above and below the words; the scale names line up with it.
    static let verticalPadding: CGFloat = 7

    let label: String
    let spoken: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                OrganicStar()
                    .fill(isOn ? Palette.accent : Palette.accentDim.opacity(0.35))
                    .frame(width: 9, height: 9)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(isOn ? Palette.text : Palette.text2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, Self.verticalPadding)
            .background {
                Capsule().fill(isOn ? Palette.accent.opacity(0.2) : Color.white.opacity(0.05))
            }
            .overlay {
                Capsule().strokeBorder(isOn ? Palette.accent.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(SymptomChipStyle())
        .animation(.snappy(duration: 0.2), value: isOn)
        .accessibilityLabel(Text(spoken))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Gives a little when pressed. The tap area is about 44 pt tall without changing the layout.
private struct SymptomChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .padding(.vertical, -6)
    }
}
