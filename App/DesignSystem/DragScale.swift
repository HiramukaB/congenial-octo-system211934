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

/// How a `DragScale` is laid out.
nonisolated enum DragScaleLayout: Sendable {
    /// The name and the value above a full-width 48 pt track: one scale on its own.
    case stacked
    /// One 44 pt row – the name and the value on the left, the track beside them – for a card with
    /// several scales. Above the "xLarge" text size it stacks, so the track keeps room for her finger.
    case compact

    /// Whether `.compact` still fits in one row at this text size.
    static func fitsCompactRow(at size: DynamicTypeSize) -> Bool {
        size <= .xLarge
    }
}

/// A scale she sets by dragging along it or by tapping anywhere on it – 1 to 10 unless told
/// otherwise. It replaces rows of small chips.
///
/// - Every step she passes ticks (selection haptic) and goes straight to `onChange`, so the value
///   saves itself while she drags; there is nothing to confirm.
/// - Unset it says "przeciągnij". Once set, "wyczyść" takes it back (`onChange(nil)`): a link next
///   to the value in `.stacked`, a long press on the name in `.compact`.
/// - `.stacked` (default): the name and the value above a full-width track, 48 pt tall.
///   `.compact`: one row – the name and the value on the left, a 44 pt track beside them – for a
///   card with several scales ("jak się dziś czujesz?"). At large text sizes it stacks.
/// - In a scroll view only a sideways drag moves the value (`SidewaysDrag`); a drag up or down
///   scrolls the page, also when it starts on the track.
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
    private let layout: DragScaleLayout
    private let onChange: (Int?) -> Void

    /// The value under her finger during a drag, before it has come back through `value`.
    @State private var dragValue: Int? = nil
    /// Counts her steps, for one haptic tick each.
    @State private var steps = 0
    @ScaledMetric(relativeTo: .body) private var stackedTrackHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var compactTrackHeight: CGFloat = 44
    /// The name column of `.compact`: wide enough for "6 · w porządku", so the tracks line up.
    @ScaledMetric(relativeTo: .body) private var compactLabelWidth: CGFloat = 98
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// `value` outside `range` is shown at the nearest end.
    init(_ title: String, value: Int?, range: ClosedRange<Int> = 1...10, words: [ScaleWord] = [],
         tint: Color = Palette.accent, layout: DragScaleLayout = .stacked, onChange: @escaping (Int?) -> Void) {
        self.title = title
        self.value = value.map { Swift.min(Swift.max($0, range.lowerBound), range.upperBound) }
        self.range = range
        self.words = words
        self.tint = tint
        self.layout = layout
        self.onChange = onChange
    }

    /// The same scale, writing straight into `value`.
    init(_ title: String, value: Binding<Int?>, range: ClosedRange<Int> = 1...10, words: [ScaleWord] = [],
         tint: Color = Palette.accent, layout: DragScaleLayout = .stacked) {
        self.init(title, value: value.wrappedValue, range: range, words: words, tint: tint, layout: layout) { newValue in
            value.wrappedValue = newValue
        }
    }

    var body: some View {
        let shown = dragValue ?? value
        scale(shown)
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

    // MARK: - Stacked and compact

    @ViewBuilder
    private func scale(_ shown: Int?) -> some View {
        if layout == .compact && DragScaleLayout.fitsCompactRow(at: dynamicTypeSize) {
            HStack(alignment: .center, spacing: Spacing.item) {
                withClearMenu(compactLabel(shown))
                track(shown, height: compactTrackHeight)
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                header(shown)
                track(shown, height: stackedTrackHeight)
            }
        }
    }

    /// `.stacked`: the name on the left; the value and "wyczyść" – or "przeciągnij" – on the right.
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

    /// `.compact`: the name, and under it the value ("6 · średnia") or "przeciągnij".
    private func compactLabel(_ shown: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let shown {
                Text(shownText(shown))
                    .font(.footnote.weight(.medium).monospacedDigit())
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(value: Double(shown)))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("przeciągnij")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: compactLabelWidth, alignment: .leading)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.2), value: shown)
    }

    /// In `.compact` there is no room for the link: once set, a long press on the name offers "wyczyść".
    @ViewBuilder
    private func withClearMenu(_ label: some View) -> some View {
        if value != nil {
            label.contextMenu {
                Button("wyczyść", action: clear)
            }
        } else {
            label
        }
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

    /// The track: a soft capsule with a dot per step, tinted up to the handle. A tap sets the step
    /// under the finger; a sideways drag moves it.
    private func track(_ shown: Int?, height: CGFloat) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.05))
                Capsule()
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                if let shown {
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.12), tint.opacity(0.34)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: fillWidth(for: shown, width: width, height: height))
                }
                ForEach(Array(range), id: \.self) { step in
                    Circle()
                        .fill(dotColor(step: step, shown: shown))
                        .frame(width: 5, height: 5)
                        .position(x: center(of: step, width: width, height: height), y: height / 2)
                }
                if let shown {
                    thumb(height: height)
                        .position(x: center(of: shown, width: width, height: height), y: height / 2)
                }
            }
            .contentShape(Rectangle())
            // The drag first, so it starts the moment the finger moves sideways; a tap is what is
            // left when it doesn't move.
            .gesture(SidewaysDrag(onChanged: { location, _ in
                select(at: location.x, width: width, height: height, isDragging: true)
            }, onEnded: { _, _ in
                dragValue = nil
            }))
            .onTapGesture(coordinateSpace: .local) { location in
                select(at: location.x, width: width, height: height, isDragging: false)
            }
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.18), value: shown)
    }

    /// The handle: a filled circle in the tint with the organic star.
    private func thumb(height: CGFloat) -> some View {
        let size = Swift.max(0, height - 10)
        return ZStack {
            Circle()
                .fill(tint)
            OrganicStar()
                .fill(Palette.onAccent)
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.25), radius: 6)
    }

    // MARK: - Geometry

    /// Where the centre of `step` sits: the first and the last step half a track height in from
    /// the ends, so the handle never pokes out.
    private func center(of step: Int, width: CGFloat, height: CGFloat) -> CGFloat {
        let inset = height / 2
        let usable = Swift.max(0, width - 2 * inset)
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return width / 2 }
        let clamped = Swift.min(Swift.max(step, range.lowerBound), range.upperBound)
        return inset + usable * CGFloat(clamped - range.lowerBound) / CGFloat(span)
    }

    /// The step nearest to `x`.
    private func step(at x: CGFloat, width: CGFloat, height: CGFloat) -> Int {
        let inset = height / 2
        let usable = width - 2 * inset
        let span = range.upperBound - range.lowerBound
        guard span > 0, usable > 0 else { return range.lowerBound }
        let fraction = (x - inset) / usable
        guard fraction.isFinite else { return range.lowerBound }
        let clamped = Swift.min(Swift.max(fraction, 0), 1)
        return range.lowerBound + Int((clamped * CGFloat(span)).rounded())
    }

    /// The tinted part reaches round the handle.
    private func fillWidth(for value: Int, width: CGFloat, height: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(width, center(of: value, width: width, height: height) + height / 2))
    }

    private func dotColor(step: Int, shown: Int?) -> Color {
        guard let shown, step <= shown else { return Palette.accentDim.opacity(0.3) }
        return tint.opacity(0.85)
    }

    // MARK: - Changes

    /// A tap or a drag at `x`: the step there, saved at once. During a drag the handle follows the
    /// finger until the value comes back through `value`.
    private func select(at x: CGFloat, width: CGFloat, height: CGFloat, isDragging: Bool) {
        let newValue = step(at: x, width: width, height: height)
        let current = dragValue ?? value
        if isDragging {
            dragValue = newValue
        }
        guard newValue != current else { return }
        steps += 1
        onChange(newValue)
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
