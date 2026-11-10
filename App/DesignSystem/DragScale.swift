import SwiftUI

/// A word for part of a scale, e.g. for energy 1–3 "niska", 4–7 "średnia", 8–10 "wysoka".
nonisolated struct ScaleWord: Hashable, Sendable {
    let range: ClosedRange<Int>
    let word: String

    init(_ range: ClosedRange<Int>, _ word: String) {
        self.range = range
        self.word = word
    }

    /// The word for `value`, or nil when none of `words` covers it.
    static func label(for value: Int, in words: [ScaleWord]) -> String? {
        words.first { $0.range.contains(value) }?.word
    }
}

/// A scale she sets by dragging along it or by tapping anywhere on it – 1 to 10 unless told
/// otherwise. It replaces rows of small chips.
///
/// - Every step she passes ticks (selection haptic) and goes straight to `onChange`, so the value
///   saves itself while she drags; there is nothing to confirm.
/// - Unset it says "przeciągnij"; once set, "wyczyść" next to the value takes it back
///   (`onChange(nil)`).
/// - The track is 48 pt tall (it grows with the text size) and as wide as its container.
/// - In a scroll view a vertical swipe still scrolls: only a sideways drag moves the value.
/// - VoiceOver: one adjustable element (swipe up or down), "wyczyść" as an action.
///
///     DragScale("energia", value: day.energy, words: [ScaleWord(1...3, "niska"), …]) { newValue in
///         store.setSymptomScale(\.energy, to: newValue, on: date)
///     }
struct DragScale: View {
    private let title: String
    private let value: Int?
    private let range: ClosedRange<Int>
    private let words: [ScaleWord]
    private let tint: Color
    private let onChange: (Int?) -> Void

    /// The value under her finger during a drag, before it has come back through `value`.
    @State private var dragValue: Int? = nil
    /// Whether the drag in progress moves along the track or is a scroll.
    @State private var dragAxis: DragAxis = .undecided
    /// True while a finger is on the track; it resets itself when the drag ends or is cancelled.
    @GestureState private var isTouching = false
    /// Counts her steps, for one haptic tick each.
    @State private var steps = 0
    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 48

    private enum DragAxis {
        case undecided, along, across
    }

    /// `value` outside `range` is shown at the nearest end.
    init(_ title: String, value: Int?, range: ClosedRange<Int> = 1...10, words: [ScaleWord] = [],
         tint: Color = Palette.accent, onChange: @escaping (Int?) -> Void) {
        self.title = title
        self.value = value.map { Swift.min(Swift.max($0, range.lowerBound), range.upperBound) }
        self.range = range
        self.words = words
        self.tint = tint
        self.onChange = onChange
    }

    /// The same scale, writing straight into `value`.
    init(_ title: String, value: Binding<Int?>, range: ClosedRange<Int> = 1...10, words: [ScaleWord] = [],
         tint: Color = Palette.accent) {
        self.init(title, value: value.wrappedValue, range: range, words: words, tint: tint) { newValue in
            value.wrappedValue = newValue
        }
    }

    var body: some View {
        let shown = dragValue ?? value
        VStack(alignment: .leading, spacing: Spacing.tight) {
            header(shown)
            track(shown)
        }
        .sensoryFeedback(.selection, trigger: steps)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(spokenValue(shown)))
        .accessibilityAdjustableAction { direction in
            adjust(direction)
        }
        .accessibilityActions {
            if value != nil {
                Button("wyczyść") {
                    clear()
                }
            }
        }
    }

    // MARK: - Parts

    private func header(_ shown: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
            Text(title)
                .font(.body)
                .foregroundStyle(Palette.text)
            Spacer(minLength: Spacing.tight)
            if let shown {
                Text(shownText(shown))
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(value: Double(shown)))
                if value != nil {
                    clearButton
                }
            } else {
                Text("przeciągnij")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
            }
        }
        .animation(.snappy(duration: 0.2), value: shown)
    }

    private var clearButton: some View {
        Button(action: clear) {
            Text("wyczyść")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
                // About 44 pt to tap, without making the line taller.
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
                .padding(.vertical, -12)
        }
        .buttonStyle(.plain)
    }

    private func track(_ shown: Int?) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.05))
                Capsule()
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                if let shown {
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.14), tint.opacity(0.38)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: fillWidth(for: shown, width: width))
                }
                ForEach(Array(range), id: \.self) { step in
                    Circle()
                        .fill(dotColor(step: step, shown: shown))
                        .frame(width: 5, height: 5)
                        .position(x: center(of: step, width: width), y: trackHeight / 2)
                }
                if let shown {
                    thumb
                        .position(x: center(of: shown, width: width), y: trackHeight / 2)
                }
            }
            .contentShape(Capsule())
            .onTapGesture(coordinateSpace: .local) { location in
                select(at: location.x, width: width)
            }
            // Simultaneous, so the scroll view around it keeps scrolling on vertical swipes.
            .simultaneousGesture(drag(width: width))
        }
        .frame(height: trackHeight)
        .animation(.snappy(duration: 0.18), value: shown)
        .onChange(of: isTouching) { _, touching in
            if !touching {
                endDrag()
            }
        }
    }

    /// The handle: a filled circle in the tint with the organic star.
    private var thumb: some View {
        let size = Swift.max(0, trackHeight - 10)
        return ZStack {
            Circle()
                .fill(tint)
            OrganicStar()
                .fill(Palette.onAccent)
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.35), radius: 8)
    }

    // MARK: - Geometry

    /// Where the centre of `step` sits: the first and the last step half a track height in from
    /// the ends, so the handle never pokes out.
    private func center(of step: Int, width: CGFloat) -> CGFloat {
        let inset = trackHeight / 2
        let usable = Swift.max(0, width - 2 * inset)
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return width / 2 }
        let clamped = Swift.min(Swift.max(step, range.lowerBound), range.upperBound)
        return inset + usable * CGFloat(clamped - range.lowerBound) / CGFloat(span)
    }

    /// The step nearest to `x`.
    private func step(at x: CGFloat, width: CGFloat) -> Int {
        let inset = trackHeight / 2
        let usable = width - 2 * inset
        let span = range.upperBound - range.lowerBound
        guard span > 0, usable > 0 else { return range.lowerBound }
        let fraction = (x - inset) / usable
        guard fraction.isFinite else { return range.lowerBound }
        let clamped = Swift.min(Swift.max(fraction, 0), 1)
        return range.lowerBound + Int((clamped * CGFloat(span)).rounded())
    }

    /// The tinted part reaches round the handle.
    private func fillWidth(for value: Int, width: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(width, center(of: value, width: width) + trackHeight / 2))
    }

    private func dotColor(step: Int, shown: Int?) -> Color {
        guard let shown, step <= shown else { return Palette.accentDim.opacity(0.3) }
        return tint.opacity(0.85)
    }

    // MARK: - Changes

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($isTouching) { _, touching, _ in
                touching = true
            }
            .onChanged { drag in
                if dragAxis == .undecided {
                    let along = abs(drag.translation.width)
                    let across = abs(drag.translation.height)
                    guard Swift.max(along, across) >= 4 else { return }
                    // Mostly up or down: a scroll, which this drag leaves alone.
                    dragAxis = along >= across ? .along : .across
                }
                guard dragAxis == .along else { return }
                select(at: drag.location.x, width: width)
            }
            .onEnded { _ in
                endDrag()
            }
    }

    private func select(at x: CGFloat, width: CGFloat) {
        let newValue = step(at: x, width: width)
        let current = dragValue ?? value
        if dragAxis == .along {
            dragValue = newValue
        }
        guard newValue != current else { return }
        steps += 1
        onChange(newValue)
    }

    private func endDrag() {
        dragAxis = .undecided
        dragValue = nil
    }

    /// VoiceOver: one step up or down; from unset, the middle of the scale.
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        var newValue = range.lowerBound + (range.upperBound - range.lowerBound) / 2
        if let value {
            if direction == .increment {
                newValue = Swift.min(value + 1, range.upperBound)
            } else if direction == .decrement {
                newValue = Swift.max(value - 1, range.lowerBound)
            } else {
                return
            }
        }
        guard newValue != value else { return }
        steps += 1
        onChange(newValue)
    }

    private func clear() {
        dragValue = nil
        guard value != nil else { return }
        steps += 1
        onChange(nil)
    }

    // MARK: - Words

    /// "7 · średnia", or "7" without words.
    private func shownText(_ shown: Int) -> String {
        guard let word = ScaleWord.label(for: shown, in: words) else { return "\(shown)" }
        return "\(shown) · \(word)"
    }

    /// "7 z 10, średnia" for VoiceOver.
    private func spokenValue(_ shown: Int?) -> String {
        guard let shown else { return "nie zaznaczono" }
        let number = "\(shown) z \(range.upperBound)"
        guard let word = ScaleWord.label(for: shown, in: words) else { return number }
        return "\(number), \(word)"
    }
}
