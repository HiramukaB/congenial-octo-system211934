import SwiftUI

extension Font {
    /// Serif display face at a fixed size. Only for text that must never grow (the one-line motto);
    /// everything else uses `displayFont`, which follows the system text size.
    /// Apple's New York for now; Fraunces from the web version can be bundled later.
    static func ahDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// Serif display text that grows with the system text size (Dynamic Type),
/// in step with the text style it sits next to.
struct DisplayFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let italic: Bool

    init(_ size: CGFloat, weight: Font.Weight, italic: Bool, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.italic = italic
    }

    private var font: Font {
        let base = Font.system(size: size, weight: weight, design: .serif)
        return italic ? base.italic() : base
    }

    func body(content: Content) -> some View {
        content.font(font)
    }
}

// The text roles of the app (DESIGN.md, "Typography"). A screen uses these instead of picking
// fonts and colours itself, so every screen reads the same way.
extension View {
    func displayFont(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false,
                     relativeTo style: Font.TextStyle) -> some View {
        modifier(DisplayFont(size, weight: weight, italic: italic, relativeTo: style))
    }

    /// Heading of a whole screen: serif, 30 pt, lowercase ("jedzenie").
    func screenTitle() -> some View {
        displayFont(30, weight: .medium, relativeTo: .title)
            .foregroundStyle(Palette.text)
    }

    /// Lowercase serif heading of a card, in the accent ("co zjadłaś"). Prefer `SectionHeader`.
    func sectionTitle() -> some View {
        displayFont(19, weight: .medium, relativeTo: .title3)
            .foregroundStyle(Palette.accent)
    }

    /// The one big number of a card (the cycle day): serif, 52 pt.
    func bigNumber() -> some View {
        displayFont(52, relativeTo: .largeTitle)
            .foregroundStyle(Palette.text)
    }

    /// Running text she reads: body size, the softer text colour, wraps instead of truncating.
    func bodyText() -> some View {
        font(.body)
            .foregroundStyle(Palette.text2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The main line of a row or a tile: her meal, a workout, a joke.
    func rowTitle() -> some View {
        font(.body)
            .foregroundStyle(Palette.text)
    }

    /// The small line under a row's title: a date, "ok. 114 kcal", a source.
    func rowDetail() -> some View {
        font(.subheadline)
            .foregroundStyle(Palette.muted)
    }

    /// A value she reads at a glance: "1075 / 1748 kcal", "4 / 8 szklanek".
    func valueText() -> some View {
        font(.body.monospacedDigit())
            .foregroundStyle(Palette.text)
    }

    /// A short hint or note. At most one per card, and only when it helps her act – longer
    /// explanations go behind `MoreInfo`.
    func hintText() -> some View {
        font(.footnote)
            .foregroundStyle(Palette.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Small uppercase label above a value ("DZIEŃ CYKLU"). Use sparingly.
    func eyebrow() -> some View {
        font(.caption.weight(.medium))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Palette.muted)
    }
}

extension String {
    /// Polish typesetting: a one-letter word (a, i, o, u, w, z) never stays alone at the end of a line.
    nonisolated var keepingShortWordsTogether: String {
        let words = split(separator: " ", omittingEmptySubsequences: false)
        var result = ""
        for (index, word) in words.enumerated() {
            result += word
            guard index < words.count - 1 else { break }
            if word.count == 1, let letter = word.first, "aiouwzAIOUWZ".contains(letter) {
                result += "\u{00A0}"
            } else {
                result += " "
            }
        }
        return result
    }
}

extension Text {
    /// Running Polish text, typeset so that one-letter words don't end a line.
    init(polish string: String) {
        self.init(verbatim: string.keepingShortWordsTogether)
    }
}
