import SwiftUI
import Charts
import AboutHerCore

/// "waga": a weekly weigh-in and a smoothed trend line – the line matters, not a single number.
struct WeightCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate

    @State private var draft = ""
    @State private var isTyping = false
    @State private var wasRejected = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let points = store.weightPoints
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("waga").sectionTitle()
                    Spacer()
                    if !isTyping {
                        StarButton(label: "dodaj pomiar", prominent: true, action: startTyping)
                    }
                }
                Text(polish: "waż się raz w tygodniu, o podobnej porze. Wahania rzędu 1–2 kg z dnia na dzień to woda i faza cyklu, nie Twoja praca – dlatego patrzymy na linię, nie na pojedynczy pomiar")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if isTyping {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        TextField("np. 64,5", text: $draft)
                            .keyboardType(.numbersAndPunctuation)
                            .submitLabel(.done)
                            .focused($isFocused)
                            .onSubmit(save)
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(Palette.text)
                            .frame(maxWidth: 120)
                        Text("kg · \(PolishDate.dayMonth(day))")
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
                        .swipeToDelete(label: "usuń pomiar") {
                            store.removeWeight(on: point.day)
                        }
                    }
                } else if !isTyping {
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
    }

    @ViewBuilder
    private func summary(points: [WeightPoint], last: WeightPoint) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ostatni pomiar: \(FoodFormat.number(last.kg)) kg (\(PolishDate.short(last.day)))")
                .font(.subheadline)
                .foregroundStyle(Palette.text)
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

    private func startTyping() {
        wasRejected = false
        draft = store.data.weights[day].map { FoodFormat.number($0) } ?? ""
        isTyping = true
        isFocused = true
    }

    private func save() {
        guard isTyping else { return }
        let text = draft.trimmingCharacters(in: .whitespaces)
        isTyping = false
        isFocused = false
        draft = ""
        guard !text.isEmpty else { return }
        if let kg = FoodFormat.parseNumber(text), store.setWeight(kg, on: day) {
            wasRejected = false
        } else {
            wasRejected = true
        }
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
        Chart {
            ForEach(points, id: \.day) { point in
                LineMark(x: .value("dzień", point.day.julianDay), y: .value("trend", point.trend))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            ForEach(points, id: \.day) { point in
                PointMark(x: .value("dzień", point.day.julianDay), y: .value("waga", point.kg))
                    .foregroundStyle(Palette.muted.opacity(0.8))
                    .symbolSize(22)
            }
        }
        .chartXScale(domain: first...Swift.max(last, first + 1))
        .chartYScale(domain: low...high)
        .chartXAxis {
            AxisMarks(values: [first, last]) { value in
                AxisValueLabel {
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
}
