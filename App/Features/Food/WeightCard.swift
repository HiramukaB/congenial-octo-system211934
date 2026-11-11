import SwiftUI
import Charts
import AboutHerCore

/// "waga": a weekly weigh-in and a smoothed trend line – the line matters, not a single number.
/// The trend leads, big; then the line, "dodaj pomiar" with the way to all weigh-ins beside it,
/// and the last weigh-in. The field opens where "dodaj pomiar" was.
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
    /// Every weigh-in is listed; otherwise only the last one.
    @State private var showsAll = false
    /// Counts the weigh-ins saved here, for one soft haptic each.
    @State private var saves = 0

    var body: some View {
        let points = store.weightPoints
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                SectionHeader("waga")
                if let last = points.last {
                    trend(points: points, last: last)
                    if points.count >= 2 {
                        WeightChart(points: points)
                    }
                }
                weighIns(points)
                if !points.isEmpty {
                    MoreInfo("dlaczego linia trendu?",
                             text: "waż się raz w tygodniu, o podobnej porze. Wahania rzędu 1–2 kg z dnia na dzień to woda i faza cyklu, nie Twoja praca – dlatego patrzymy na linię, nie na pojedynczy pomiar")
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: saves)
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

    // MARK: - Parts

    /// The open field: the number large, and the day it saves to.
    private func field(for target: LocalDate) -> some View {
        let unitAndDay: String = target == store.today ? "kg · dziś" : "kg · \(PolishDate.dayMonth(target))"
        return HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
            TextField("np. 64,5", text: $draft)
                .keyboardType(.numbersAndPunctuation)
                .submitLabel(.done)
                .focused($isFocused)
                .onSubmit { save() }
                .font(.title2.monospacedDigit())
                .foregroundStyle(Palette.text)
                .accessibilityLabel(Text("waga w kilogramach"))
                // In case the focus asked for together with showing the field didn't take.
                .onAppear { isFocused = true }
            Text(unitAndDay)
                .rowDetail()
        }
        .fieldBox()
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            isFocused = true
        })
    }

    /// The trend is what her targets use, so it leads, big; how it moved sits beside it.
    @ViewBuilder
    private func trend(points: [WeightPoint], last: WeightPoint) -> some View {
        let trendKg = WeightTrend.trend(on: store.today, in: points) ?? last.trend
        let month = WeightTrend.change(in: points, overDays: 28, endingAt: store.today)
        let sinceStart = WeightTrend.changeSinceStart(in: points)
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.item) {
                trendNumber(trendKg)
                Spacer(minLength: Spacing.item)
                changes(month: month, sinceStart: sinceStart, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: Spacing.item) {
                trendNumber(trendKg)
                changes(month: month, sinceStart: sinceStart, alignment: .leading)
            }
        }
    }

    private func trendNumber(_ trend: Double) -> some View {
        VStack(alignment: .leading, spacing: Spacing.hairline) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.hairline) {
                Text(verbatim: FoodFormat.number(trend))
                    .bigNumber()
                Text("kg")
                    .font(.title3)
                    .foregroundStyle(Palette.text2)
            }
            Text("linia trendu")
                .rowDetail()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "linia trendu: \(FoodFormat.number(trend)) kg"))
    }

    /// "−0,8 kg w 4 tygodnie" and "−1,1 kg od początku", when there is enough to say them.
    @ViewBuilder
    private func changes(month: Double?, sinceStart: Double?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Spacing.item) {
            if let month {
                change(value: month, label: "w 4 tygodnie", alignment: alignment)
            }
            if let sinceStart {
                change(value: sinceStart, label: "od początku", alignment: alignment)
            }
        }
    }

    private func change(value: Double, label: String, alignment: HorizontalAlignment) -> some View {
        let text = "\(FoodFormat.signed(value)) kg"
        return VStack(alignment: alignment, spacing: 2) {
            Text(verbatim: text)
                .valueText()
            Text(label)
                .rowDetail()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(label): \(text)"))
    }

    /// "dodaj pomiar" – or the open field in its place – then the last weigh-in, or all of them,
    /// newest first. Tap one to correct it, swipe left to delete it. Before the first weigh-in the
    /// empty state offers "dodaj pomiar".
    private func weighIns(_ points: [WeightPoint]) -> some View {
        let newestFirst = Array(points.reversed())
        let shown = showsAll ? newestFirst : Array(newestFirst.prefix(1))
        return VStack(alignment: .leading, spacing: Spacing.item) {
            // The field always opens in this one place, so it keeps the keyboard while she moves
            // from one weigh-in to another.
            if let editingDay {
                field(for: editingDay)
            } else if points.isEmpty {
                EmptyState(title: "tu pojawi się linia trendu",
                           message: "waż się raz w tygodniu, o podobnej porze",
                           actionTitle: "dodaj pomiar",
                           action: { startTyping(for: day) })
            } else {
                actions(count: points.count)
            }
            if wasRejected {
                Text(polish: "tego nie zapiszę – wpisz wagę w kilogramach, np. 64,5")
                    .font(.footnote)
                    .foregroundStyle(Palette.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !shown.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.day) { index, point in
                        if index > 0 {
                            RowDivider()
                        }
                        ListRow(PolishDate.dayMonth(point.day), detail: index == 0 ? "ostatni pomiar" : nil) {
                            Text(verbatim: "\(FoodFormat.number(point.kg)) kg")
                                .valueText()
                        }
                        .swipeToDelete(label: "usuń pomiar", onTap: { startTyping(for: point.day) }) {
                            if editingDay == point.day {
                                // The open field must not bring the deleted weigh-in back.
                                closeField()
                            }
                            store.removeWeight(on: point.day)
                        }
                    }
                }
            }
        }
    }

    /// "dodaj pomiar" with the way to all weigh-ins beside it – one under the other when the text
    /// is large.
    @ViewBuilder
    private func actions(count: Int) -> some View {
        if count > 1 {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    addButton
                    Spacer(minLength: Spacing.item)
                    historyToggle(count: count)
                }
                VStack(alignment: .leading, spacing: Spacing.tight) {
                    addButton
                    historyToggle(count: count)
                }
            }
        } else {
            addButton
        }
    }

    private var addButton: some View {
        StarActionButton("dodaj pomiar", size: .regular) {
            startTyping(for: day)
        }
    }

    /// "wszystkie pomiary (8)", or "zwiń" while they are all listed.
    private func historyToggle(count: Int) -> some View {
        let title: String = showsAll ? "zwiń" : "wszystkie pomiary (\(count))"
        return Button {
            withAnimation(.smooth(duration: 0.25)) {
                showsAll.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(showsAll ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(LinkButtonStyle(font: .footnote.weight(.medium)))
    }

    // MARK: - Saving

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
        if store.setWeight(kilograms, on: target) {
            saves += 1
        }
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
        .frame(height: 150)
        .accessibilityLabel("wykres wagi z linią trendu")
    }

    /// "pomiar 64,8 kg, linia trendu 65,1 kg"
    private static func spokenValue(of point: WeightPoint) -> String {
        "pomiar \(FoodFormat.number(point.kg)) kg, linia trendu \(FoodFormat.number(point.trend)) kg"
    }
}
