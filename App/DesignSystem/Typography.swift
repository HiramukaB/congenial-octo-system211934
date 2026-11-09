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

extension View {
    func displayFont(_ size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false,
                     relativeTo style: Font.TextStyle) -> some View {
        modifier(DisplayFont(size, weight: weight, italic: italic, relativeTo: style))
    }

    /// Small uppercase label above a value ("DZIEŃ CYKLU").
    func eyebrow() -> some View {
        font(.caption.weight(.medium))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Palette.muted)
    }

    /// Lowercase serif heading of a card.
    func sectionTitle() -> some View {
        displayFont(17, weight: .medium, relativeTo: .headline)
            .foregroundStyle(Palette.accent)
    }

    /// Heading of a whole tab.
    func screenTitle() -> some View {
        displayFont(30, weight: .medium, relativeTo: .title)
            .foregroundStyle(Palette.text)
    }

    /// Regular running text inside cards.
    func bodyText() -> some View {
        font(.subheadline)
            .foregroundStyle(Palette.text2)
            .fixedSize(horizontal: false, vertical: true)
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
