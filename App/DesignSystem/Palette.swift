import SwiftUI

/// Colours taken over from the web version: a warm night with a champagne accent.
/// Never red: nothing in the app is alarming. See DESIGN.md for which text colour goes where.
enum Palette {
    static let background = Color(hex: 0x0B0A09)
    static let card = Color(hex: 0x1E1D1B)
    /// Her own words, values, row titles, screen titles.
    static let text = Color(hex: 0xF0EEEA)
    /// Running text she reads: descriptions, body copy (about 10:1 on a card).
    static let text2 = Color(hex: 0xC9C7C2)
    /// Only hints and metadata – dates, units, "zapiszę, gdy…" – never something she needs to act
    /// on. Lighter than the web's #8A8A88, so small text keeps about 6.5:1 on the frosted cards.
    static let muted = Color(hex: 0xA8A6A1)
    static let line = Color(hex: 0x2A2A28)
    /// Headings of cards, links, the stars, what is on or chosen.
    static let accent = Color(hex: 0xD6CDB4)
    static let accentDim = Color(hex: 0xA8A08C)
    static let accentBackground = Color(hex: 0x2B2926)
    /// Text on top of a filled accent shape.
    static let onAccent = Color(hex: 0x2A2418)
    static let green = Color(hex: 0x9BC29B)
    /// Behind the bin of a row swiped open: a warm, quiet clay – never an alarming red.
    static let removeBackground = Color(hex: 0x4A3B33)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
