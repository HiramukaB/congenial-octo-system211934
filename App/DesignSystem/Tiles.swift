import SwiftUI

/// A yes/no item as a large tile – at least 56 pt tall, two to a row in a `TileGrid`. On: a filled
/// star, a warm accent tint and a brighter label. Off: an outlined star on a quiet tile. Never red.
/// A tap toggles it and ticks (selection haptic); `action` saves at once.
///
///     TileGrid {
///         ForEach(SymptomFlag.allCases, id: \.self) { flag in
///             ToggleTile(title: flag.label, isOn: marked.flags.contains(flag)) { … }
///         }
///     }
struct ToggleTile: View {
    let title: String
    let isOn: Bool
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: Spacing.tight + 2) {
                ZStack {
                    OrganicStar()
                        .fill(isOn ? Palette.accent : Color.clear)
                    OrganicStar()
                        .stroke(isOn ? Palette.accent : Palette.accentDim.opacity(0.7), lineWidth: 1.2)
                }
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Palette.text : Palette.text2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.item + 2)
            .padding(.vertical, Spacing.tight)
            .frame(maxWidth: .infinity, minHeight: TapSize.large, alignment: .leading)
            .background {
                shape.fill(isOn ? Palette.accent.opacity(0.16) : Color.white.opacity(0.04))
            }
            .overlay {
                shape.strokeBorder(isOn ? Palette.accent.opacity(0.55) : Color.white.opacity(0.09), lineWidth: 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(TilePressStyle())
        .animation(.snappy(duration: 0.2), value: isOn)
        .sensoryFeedback(.selection, trigger: taps)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// One choice out of a few, as large tiles: e.g. "żart · cytat · coś innego". The chosen one looks
/// like a tile that is on; a tap on another chooses it.
struct ChoiceTiles<Option: Hashable>: View {
    let options: [Option]
    let selection: Option?
    var columns = 2
    let label: (Option) -> String
    let onSelect: (Option) -> Void

    var body: some View {
        TileGrid(columns: columns) {
            ForEach(options, id: \.self) { option in
                ToggleTile(title: label(option), isOn: option == selection) {
                    onSelect(option)
                }
            }
        }
    }
}

/// Tiles in even columns – two by default – 8 pt apart.
struct TileGrid<Content: View>: View {
    var columns = 2
    @ViewBuilder var content: Content

    var body: some View {
        let count = Swift.max(1, columns)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.tight), count: count),
                  spacing: Spacing.tight) {
            content
        }
    }
}

/// Gives a little when pressed.
struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
