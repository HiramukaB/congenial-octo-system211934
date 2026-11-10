import SwiftUI
import AboutHerCore

/// "jak się dziś czujesz?" on "dziś": energy, mood, sleep and appetite, each dragged from 1 to 10,
/// and her symptoms as large tiles behind "objawy". Every change saves itself at once – there is
/// nothing to confirm. The calendar's sheet shows the same form for any day she has lived.
struct SymptomsCard: View {
    let day: LocalDate
    /// Whether the symptom tiles are open; they stay as she left them.
    @AppStorage("symptomsFlagsOpen") private var isFlagsOpen = false

    var body: some View {
        Card {
            DaySymptomsForm(day: day, isFlagsOpen: $isFlagsOpen)
        }
    }

    /// "jak się dziś czujesz?" for today; the days before in the past tense:
    /// "jak się czułaś wczoraj?", "jak się czułaś przedwczoraj?", "jak się czułaś 7 listopada?".
    static func title(on day: LocalDate, today: LocalDate) -> String {
        if day == today {
            return "jak się dziś czujesz?"
        }
        if day == today.adding(days: -1) {
            return "jak się czułaś wczoraj?"
        }
        if day == today.adding(days: -2) {
            return "jak się czułaś przedwczoraj?"
        }
        let date = PolishDate.dayMonth(day)
        return day.year == today.year ? "jak się czułaś \(date)?" : "jak się czułaś \(date) \(day.year)?"
    }
}

/// How she felt on one day: the four scales, then her symptoms. On "dziś" the symptoms wait behind
/// "objawy" (with what she marked named on the row); in the calendar's sheet they are always open.
struct DaySymptomsForm: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate
    /// Whether the symptom tiles show; nil keeps them always open.
    var isFlagsOpen: Binding<Bool>? = nil

    var body: some View {
        let marked = store.data.symptoms(on: day)
        let isToday = day == store.today
        VStack(alignment: .leading, spacing: Spacing.cardGap) {
            SectionHeader(SymptomsCard.title(on: day, today: store.today))
            VStack(alignment: .leading, spacing: Spacing.group) {
                ForEach(SymptomScaleKind.allCases, id: \.self) { kind in
                    DragScale(kind.title, value: marked[keyPath: kind.keyPath], words: kind.words) { value in
                        _ = store.setSymptomScale(kind.keyPath, to: value, on: day)
                    }
                }
            }
            if marked.hasEveryScale {
                ConfirmationNote(text: isToday ? "zapisałam – dziękuję, że o siebie dbasz" : "zapisałam")
            }
            RowDivider()
            flagsSection(marked)
        }
        .animation(.smooth(duration: 0.25), value: marked.hasEveryScale)
    }

    @ViewBuilder
    private func flagsSection(_ marked: SymptomDay) -> some View {
        if let isFlagsOpen {
            VStack(alignment: .leading, spacing: Spacing.item) {
                SymptomsFlagsRow(summary: summary(of: marked), isOpen: isFlagsOpen.wrappedValue) {
                    withAnimation(.smooth(duration: 0.25)) {
                        isFlagsOpen.wrappedValue = !isFlagsOpen.wrappedValue
                    }
                }
                if isFlagsOpen.wrappedValue {
                    flagTiles(marked)
                        .transition(.opacity)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.item) {
                Text("objawy")
                    .rowTitle()
                    .accessibilityAddTraits(.isHeader)
                flagTiles(marked)
            }
        }
    }

    /// Two tiles to a row; a tap marks a symptom, a second one takes it back.
    private func flagTiles(_ marked: SymptomDay) -> some View {
        TileGrid(columns: 2) {
            ForEach(SymptomFlag.allCases, id: \.self) { flag in
                ToggleTile(title: flag.label, isOn: marked.flags.contains(flag)) {
                    _ = store.toggleSymptom(flag, on: day)
                }
            }
        }
    }

    /// "wzdęcia, skurcze"; nil while nothing is marked.
    private func summary(of marked: SymptomDay) -> String? {
        let names = marked.orderedFlags.map(\.label)
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}

/// The row that opens and closes the symptom tiles: "objawy", what she marked, a chevron.
private struct SymptomsFlagsRow: View {
    let summary: String?
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.item) {
                Text("objawy")
                    .rowTitle()
                Spacer(minLength: Spacing.tight)
                if let summary {
                    Text(summary)
                        .rowDetail()
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: TapSize.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("objawy"))
        .accessibilityValue(Text(spokenValue))
    }

    /// "wzdęcia, zwinięte" – what is marked, and whether the tiles show.
    private var spokenValue: String {
        let marked = summary ?? "nic nie zaznaczono"
        return "\(marked), \(isOpen ? "rozwinięte" : "zwinięte")"
    }
}
