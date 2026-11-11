import SwiftUI
import AboutHerCore

/// The minutes of a workout, set by dragging along a track or tapping anywhere on it, in the steps
/// of `WorkoutMinuteSteps`: every 5 minutes up to an hour, then 15, then 30, up to four hours.
/// `DragScale` can't do this (it counts 1–10), so this one is its sibling for minutes and looks
/// and moves the same way:
///
/// - Every step she passes ticks and goes straight to `onChange`, so the minutes save themselves
///   while she drags; there is nothing to confirm.
/// - In a scroll view only a sideways drag moves the value (`SidewaysDrag`); a drag up or down
///   scrolls the page, also when it starts on the track.
/// - VoiceOver: one adjustable element, one step at a time ("30 minut").
/// - Minutes between two steps (typed in an older version) show as they are; the handle sits on
///   the nearest step until she moves it.
struct WorkoutMinutesScale: View {
    private let minutes: Int
    /// Saves the minutes; called on every step.
    private let save: (Int) -> Void

    /// The minutes under her finger during a drag, before they have come back through `minutes`.
    @State private var dragMinutes: Int? = nil
    /// Counts her steps, for one haptic tick each.
    @State private var steps = 0
    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 48

    init(minutes: Int, onChange: @escaping (Int) -> Void) {
        self.minutes = minutes
        self.save = onChange
    }

    var body: some View {
        let shown = dragMinutes ?? minutes
        VStack(alignment: .leading, spacing: Spacing.tight) {
            header(shown)
            track(shown)
        }
        .sensoryFeedback(.selection, trigger: steps)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("minuty"))
        .accessibilityValue(Text(MovementFormat.spokenMinutes(shown)))
        .accessibilityAdjustableAction { direction in
            adjust(direction)
        }
        .accessibilityIdentifier("workout-minutes")
    }

    // MARK: - Parts

    private func header(_ shown: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.tight) {
            Text("minuty")
                .font(.body)
                .foregroundStyle(Palette.text)
            Spacer(minLength: Spacing.tight)
            Text(verbatim: "\(shown) min")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(Palette.accent)
                .contentTransition(.numericText(value: Double(shown)))
        }
        .animation(.snappy(duration: 0.2), value: shown)
    }

    private func track(_ shown: Int) -> some View {
        let index = WorkoutMinuteSteps.nearestIndex(to: shown)
        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.05))
                Capsule()
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                Capsule()
                    .fill(LinearGradient(colors: [Palette.accent.opacity(0.12), Palette.accent.opacity(0.34)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: fillWidth(for: index, width: width))
                ForEach(WorkoutMinuteSteps.values.indices, id: \.self) { mark in
                    Circle()
                        .fill(mark <= index ? Palette.accent.opacity(0.85) : Palette.accentDim.opacity(0.3))
                        .frame(width: 4, height: 4)
                        .position(x: center(of: mark, width: width), y: trackHeight / 2)
                }
                thumb
                    .position(x: center(of: index, width: width), y: trackHeight / 2)
            }
            .contentShape(Rectangle())
            // The drag first, so it starts the moment the finger moves sideways; a tap is what is
            // left when it doesn't move.
            .gesture(SidewaysDrag(onChanged: { location, _ in
                select(at: location.x, width: width, isDragging: true)
            }, onEnded: { _, _ in
                dragMinutes = nil
            }))
            .onTapGesture(coordinateSpace: .local) { location in
                select(at: location.x, width: width, isDragging: false)
            }
        }
        .frame(height: trackHeight)
        .animation(.snappy(duration: 0.18), value: index)
    }

    /// The handle: a filled circle in the accent with the organic star.
    private var thumb: some View {
        let size = Swift.max(0, trackHeight - 10)
        return ZStack {
            Circle()
                .fill(Palette.accent)
            OrganicStar()
                .fill(Palette.onAccent)
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.accent.opacity(0.25), radius: 6)
    }

    // MARK: - Geometry

    /// Where the centre of step `index` sits: the first and the last step half a track height in
    /// from the ends, so the handle never pokes out.
    private func center(of index: Int, width: CGFloat) -> CGFloat {
        let inset = trackHeight / 2
        let usable = Swift.max(0, width - 2 * inset)
        let span = WorkoutMinuteSteps.values.count - 1
        guard span > 0 else { return width / 2 }
        let clamped = Swift.min(Swift.max(index, 0), span)
        return inset + usable * CGFloat(clamped) / CGFloat(span)
    }

    /// The index of the step nearest to `x`.
    private func stepIndex(at x: CGFloat, width: CGFloat) -> Int {
        let inset = trackHeight / 2
        let usable = width - 2 * inset
        let span = WorkoutMinuteSteps.values.count - 1
        guard span > 0, usable > 0 else { return 0 }
        let fraction = (x - inset) / usable
        guard fraction.isFinite else { return 0 }
        let clamped = Swift.min(Swift.max(fraction, 0), 1)
        return Int((clamped * CGFloat(span)).rounded())
    }

    /// The tinted part reaches round the handle.
    private func fillWidth(for index: Int, width: CGFloat) -> CGFloat {
        Swift.max(0, Swift.min(width, center(of: index, width: width) + trackHeight / 2))
    }

    // MARK: - Changes

    /// A tap or a drag at `x`: the step there, saved at once. During a drag the handle follows the
    /// finger until the minutes come back through `minutes`.
    private func select(at x: CGFloat, width: CGFloat, isDragging: Bool) {
        let newValue = WorkoutMinuteSteps.value(at: stepIndex(at: x, width: width))
        let current = dragMinutes ?? minutes
        if isDragging {
            dragMinutes = newValue
        }
        guard newValue != current else { return }
        steps += 1
        save(newValue)
    }

    /// VoiceOver: one step up or down from the minutes she has.
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        var target: Int? = nil
        if direction == .increment {
            target = WorkoutMinuteSteps.step(above: minutes)
        } else if direction == .decrement {
            target = WorkoutMinuteSteps.step(below: minutes)
        }
        guard let newValue = target, newValue != minutes else { return }
        steps += 1
        save(newValue)
    }
}
