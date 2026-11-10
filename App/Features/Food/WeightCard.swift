import SwiftUI
import Charts
import AboutHerCore

/// "waga": a weekly weigh-in and a smoothed trend line – the line matters, not a single number.
///
/// The field saves itself: on "gotowe", when she leaves it, when the shown day changes and when
/// the app goes to the background. It always saves to its own day – the shown day, or the
/// weigh-in she tapped – so nothing lands on a day she didn't mean.
struct WeightCard: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    let day: LocalDate

    @State private var draft = ""
    /// The day the open field saves to; nil while the field is closed.
    @State private var editingDay: LocalDate? = nil
    /// The last number she typed couldn't be a weight.
    @State private var wasRejected = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let points = store.weightPoints
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("waga").sectionTitle()
                    Spacer()
                    if editingDay == nil {
                        StarButton(label: "dodaj pomiar", prominent: true, action: { startTyping(for: day) })
                    }
                }
                Text(polish: "waż się raz w tygodniu, o podobnej porze. Wahania rzędu 1–2 kg z dnia na dzień to woda i faza cyklu, nie Twoja praca – dlatego patrzymy na linię, nie na pojedynczy pomiar")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let editingDay {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("np. 64,5", text: $draft)
                            .keyboardType(.numbersAndPunctuation)
                            .submitLabel(.done)
                            .focused($isFocused)
                            .onSubmit { save() }
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(Palette.text)
                            .frame(maxWidth: 120)
                            // In case the focus asked for together with showing the field didn't take.
                            .onAppear { isFocused = true }
                        Text("kg · \(PolishDate.dayMonth(editingDay))")
                            .font(.subheadline)
                            .foregroundStyle(Palette.muted)
                    }
                }
                if wasRejected {
                    Text(polish: "tego nie zapiszę – wpisz wagę w kilogramach, np. 64,5")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                }
                if let last = points.last {
                    summary(points: points, last: last)
                    if points.count >= 2 {
                        WeightChart(points: points)
                    }
                    ForEach(points.suffix(6).reversed(), id: \.day) { point in
                        HStack {
                            Text(PolishDate.dayMonth(point.day))
                                .font(.subheadline)
                                .foregroundStyle(Palette.text2)
                            Spacer()
                            Text("\(FoodFormat.number(point.kg)) kg")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Palette.text)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        // Tap to correct it, swipe left to delete it.
                        .swipeToDelete(label: "usuń pomiar", onTap: { startTyping(for: point.day) }) {
                            if editingDay == point.day {
                                // The open field must not bring the deleted weigh-in back.
                                closeField()
                            }
                            store.removeWeight(on: point.day)
                        }
                    }
                } else if editingDay == nil {
                    Text(polish: "tu pojawi się linia trendu, gdy zapiszesz pierwsze pomiary")
                        .bodyText()
                }
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                save()
            }
        }
        .onChange(of: day) {
            // Another day is shown (her switch, midnight, a new day on opening the app):
            // what she typed goes to the day the field belongs to.
            save()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && editingDay != nil {
                save()
                // Changes are written after a short delay; the app may not get that far.
                store.saveNow()
            }
        }
        .onDisappear {
            // Another tab or screen took over before the field lost focus.
            save()
        }
    }

    @ViewBuilder
    private func summary(points: [WeightPoint], last: WeightPoint) -> some View {
        // The trend is what her targets use, so it leads; the last weigh-in is secondary.
        let trend = WeightTrend.trend(on: store.today, in: points) ?? last.trend
        VStack(alignment: .leading, spacing: 3) {
            Text("linia trendu: \(FoodFormat.number(trend)) kg")
                .font(.headline.monospacedDigit())
                .foregroundStyle(Palette.text)
            Text("ostatni pomiar: \(FoodFormat.number(last.kg)) kg (\(PolishDate.short(last.day)))")
                .font(.footnote)
                .foregroundStyle(Palette.text2)
            if let sinceStart = WeightTrend.changeSinceStart(in: points) {
                Text("linia trendu od początku: \(FoodFormat.signed(sinceStart)) kg")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
            }
            if let month = WeightTrend.change(in: points, overDays: 28, endingAt: store.today) {
                Text("ostatnie 4 tygodnie: \(FoodFormat.signed(month)) kg")
                    .font(.footnote)
                    .foregroundStyle(Palette.text2)
            }
        }
    }

    /// Opens the field for `target`, pre-filled with its weigh-in. A field already open for
    /// another day is saved first.
    private func startTyping(for target: LocalDate) {
        if let open = editingDay {
            guard open != target else {
                isFocused = true
                return
            }
            save()
        } else {
            wasRejected = false
        }
        draft = store.data.weights[target].map { FoodFormat.number($0) } ?? ""
        editingDay = target
        isFocused = true
    }

    /// Saves the open field to its own day and closes it. An empty field changes nothing.
    private func save() {
        guard let target = editingDay else { return }
        let text = draft.trimmingCharacters(in: .whitespaces)
        closeField()
        guard !text.isEmpty else { return }
        guard let kilograms = FoodFormat.parseNumber(text), (25...250).contains(kilograms) else {
            // Only a number that can't be a weight gets this line. When the store refuses
            // for another reason (read-only data), it shows its own alert.
            wasRejected = true
            return
        }
        wasRejected = false
        store.setWeight(kilograms, on: target)
    }

    private func closeField() {
        editingDay = nil
        isFocused = false
        draft = ""
    }
}

/// The smoothed trend (line) over the raw weigh-ins (faint dots).
struct WeightChart: View {
    let points: [WeightPoint]

    var body: some View {
        let values = points.flatMap { [$0.kg, $0.trend] }
        let low = (values.min() ?? 0) - 0.5
        let high = (values.max() ?? 0) + 0.5
        let first = points.first?.day.julianDay ?? 0
        let last = points.last?.day.julianDay ?? 0
        // VoiceOver reads each point as its date and her numbers, not the day number that places it.
        let spokenValues: [LocalDate: String] = Dictionary(points.map { ($0.day, Self.spokenValue(of: $0)) },
                                                           uniquingKeysWith: { earlier, _ in earlier })
        Chart {
            ForEach(points, id: \.day) { point in
                LineMark(x: .value("dzień", point.day.julianDay), y: .value("linia trendu", point.trend))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .accessibilityLabel(PolishDate.dayMonth(point.day))
                    .accessibilityValue(spokenValues[point.day] ?? "")
            }
            ForEach(points, id: \.day) { point in
                PointMark(x: .value("dzień", point.day.julianDay), y: .value("pomiar", point.kg))
                    .foregroundStyle(Palette.muted.opacity(0.8))
                    .symbolSize(22)
                    // Already read with the line above.
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: first...Swift.max(last, first + 1))
        .chartYScale(domain: low...high)
        .chartXAxis {
            AxisMarks(values: [first, last]) { value in
                // The first date starts at the left edge and the last one ends at the right edge,
                // so neither is cut off.
                AxisValueLabel(anchor: value.as(Int.self) == first ? UnitPoint.topLeading : UnitPoint.topTrailing) {
                    if let julianDay = value.as(Int.self) {
                        Text(PolishDate.short(LocalDate(julianDay: julianDay)))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Palette.line)
                AxisValueLabel()
            }
        }
        .frame(height: 140)
        .accessibilityLabel("wykres wagi z linią trendu")
    }

    /// "pomiar 64,8 kg, linia trendu 65,1 kg"
    private static func spokenValue(of point: WeightPoint) -> String {
        "pomiar \(FoodFormat.number(point.kg)) kg, linia trendu \(FoodFormat.number(point.trend)) kg"
    }
}
