import SwiftUI

/// Colours taken over from the web version: a warm night with a champagne accent.
enum Palette {
    static let background = Color(hex: 0x0B0A09)
    static let card = Color(hex: 0x1E1D1B)
    static let text = Color(hex: 0xF0EEEA)
    static let text2 = Color(hex: 0xC9C7C2)
    static let muted = Color(hex: 0x8A8A88)
    static let line = Color(hex: 0x2A2A28)
    static let accent = Color(hex: 0xD6CDB4)
    static let accentDim = Color(hex: 0xA8A08C)
    static let accentBackground = Color(hex: 0x2B2926)
    /// Text on top of a filled accent shape.
    static let onAccent = Color(hex: 0x2A2418)
    static let green = Color(hex: 0x9BC29B)
    static let red = Color(hex: 0xD98A8A)
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
