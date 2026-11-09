import SwiftUI

extension Font {
    /// Serif display face. Apple's New York for now; Fraunces from the web version can be bundled later.
    static func ahDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension View {
    /// Small uppercase label above a value ("DZIEŃ CYKLU").
    func eyebrow() -> some View {
        font(.caption.weight(.medium))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Palette.muted)
    }

    /// Lowercase serif heading of a card.
    func sectionTitle() -> some View {
        font(.ahDisplay(17, weight: .medium))
            .foregroundStyle(Palette.accent)
    }

    /// Heading of a whole tab.
    func screenTitle() -> some View {
        font(.ahDisplay(30, weight: .medium))
            .foregroundStyle(Palette.text)
    }

    /// Regular running text inside cards.
    func bodyText() -> some View {
        font(.subheadline)
            .foregroundStyle(Palette.text2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
