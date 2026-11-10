import SwiftUI
import AboutHerCore

/// "woda": eight glasses that fill as she drinks. One tap on the big tile adds a glass – to the part
/// of the day it is now, or on an earlier day where it keeps the day evenly spread (`WaterDay`'s
/// `slotForNewGlass`). The round arrow beside it takes one back.
struct WaterCard: View {
    @Environment(AppStore.self) private var store
    let day: LocalDate

    /// Where the glasses added here went, newest last, so the arrow takes those back first.
    @State private var added: [WaterDay.Slot] = []
    /// Count her taps that changed something, for one haptic each.
    @State private var adds = 0
    @State private var undos = 0

    var body: some View {
        let waterDay = store.data.water(on: day)
        let goal = WaterDay.goalGlasses
        Card {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                // Names the day whenever it isn't today, as the meal card does, so a glass never
                // lands on another day unnoticed.
                SectionHeader("woda", subtitle: day == store.today ? nil : PolishDate.long(day)) {
                    Text(verbatim: "\(waterDay.total) z \(goal) szklanek")
                        .valueText()
                        .contentTransition(.numericText(value: Double(waterDay.total)))
                        .animation(.smooth, value: waterDay.total)
                }
                WaterGlasses(count: waterDay.total, goal: goal)
                HStack(spacing: Spacing.tight) {
                    addButton
                    undoButton(isEnabled: waterDay.total > 0)
                }
                // Both tiles as tall as the taller one, also at large text sizes.
                .fixedSize(horizontal: false, vertical: true)
                Text(polish: note(for: waterDay, goal: goal))
                    .hintText()
            }
        }
        .sensoryFeedback(.increase, trigger: adds)
        .sensoryFeedback(.decrease, trigger: undos)
        .onChange(of: day) {
            added.removeAll()
        }
    }

    // MARK: - Parts

    private var addButton: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        return Button(action: add) {
            HStack(spacing: Spacing.item) {
                OrganicStar()
                    .fill(Palette.accent)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text("dodaj szklankę")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.text)
            }
            .padding(.horizontal, Spacing.item)
            .padding(.vertical, Spacing.tight)
            .frame(maxWidth: .infinity, minHeight: TapSize.large)
            .background {
                shape.fill(Palette.accent.opacity(0.14))
            }
            .overlay {
                shape.strokeBorder(Palette.accent.opacity(0.4), lineWidth: 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(TilePressStyle())
    }

    private func undoButton(isEnabled: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        return Button(action: undo) {
            Image(systemName: "arrow.uturn.backward")
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.text2)
                .frame(minWidth: TapSize.large, maxWidth: TapSize.large,
                       minHeight: TapSize.large, maxHeight: .infinity)
                .background {
                    shape.fill(Color.white.opacity(0.04))
                }
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                }
                .contentShape(shape)
        }
        .buttonStyle(TilePressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel("cofnij szklankę")
    }

    /// One short line: when she drank today, or – on a day without water – the gentle guide.
    private func note(for waterDay: WaterDay, goal: Int) -> String {
        let parts = WaterDay.Slot.allCases.compactMap { slot -> String? in
            let count = waterDay.count(in: slot)
            return count > 0 ? "\(slot.label) \(count)" : nil
        }
        guard !parts.isEmpty else {
            return "ok. \(PolishPlural.glasses(goal)) dziennie, mniej wieczorem"
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Changes

    private func add() {
        let before = store.data.water(on: day)
        let hour = Calendar.current.component(.hour, from: Date())
        let slot = before.slotForNewGlass(isToday: day == store.today, hour: hour)
        store.addWater(1, to: slot, on: day)
        // The store refuses another day than today or earlier, and read-only data.
        guard store.data.water(on: day).total > before.total else { return }
        added.append(slot)
        adds += 1
    }

    private func undo() {
        let before = store.data.water(on: day)
        guard let slot = before.slotToTakeBack(preferring: added.last) else { return }
        store.addWater(-1, to: slot, on: day)
        guard store.data.water(on: day).total < before.total else { return }
        if added.last == slot {
            added.removeLast()
        }
        undos += 1
    }
}

/// The day's glasses, filled up to what she drank – up to the guide of eight.
private struct WaterGlasses: View {
    let count: Int
    let goal: Int

    var body: some View {
        HStack(spacing: Spacing.tight) {
            ForEach(0..<Swift.max(goal, 0), id: \.self) { index in
                WaterGlass(isFull: index < count)
            }
        }
        .frame(maxWidth: .infinity)
        // The header says it in words: "4 z 8 szklanek".
        .accessibilityHidden(true)
    }
}

/// One glass: an outline, and water that rises in it when it is drunk.
private struct WaterGlass: View {
    let isFull: Bool

    private static let height: CGFloat = 40

    var body: some View {
        ZStack {
            WaterGlassShape()
                .fill(Color.white.opacity(0.04))
            WaterGlassShape()
                .fill(Palette.accent.opacity(0.8))
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: isFull ? Self.height * 0.8 : 0)
                }
            WaterGlassShape(isOpen: true)
                .stroke(isFull ? Palette.accent.opacity(0.7) : Palette.accentDim.opacity(0.45),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
        }
        .frame(maxWidth: 34)
        .frame(height: Self.height)
        .animation(.smooth(duration: 0.35), value: isFull)
    }
}

/// A tumbler: the rim as wide as the frame, the base a little narrower, soft lower corners.
/// `isOpen` leaves out the rim line, for the outline. `nonisolated`, like `OrganicStar`.
nonisolated struct WaterGlassShape: Shape {
    var isOpen = false

    func path(in rect: CGRect) -> Path {
        let taper = rect.width * 0.12
        let corner = Swift.min(rect.width * 0.2, rect.height * 0.2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + taper, y: rect.maxY - corner))
        path.addQuadCurve(to: CGPoint(x: rect.minX + taper + corner, y: rect.maxY),
                          control: CGPoint(x: rect.minX + taper, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - taper - corner, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - taper, y: rect.maxY - corner),
                          control: CGPoint(x: rect.maxX - taper, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        if !isOpen {
            path.closeSubpath()
        }
        return path
    }
}
