import CoreGraphics

/// The spacing scale. Every gap in the app is one of these, so all screens breathe alike.
/// `nonisolated`, so layouts and shapes may use it too.
nonisolated enum Spacing {
    /// 4 pt – a title and the one short line under it.
    static let hairline: CGFloat = 4
    /// 8 pt – an icon and its label; tiles in a grid.
    static let tight: CGFloat = 8
    /// 12 pt – items of one group inside a card.
    static let item: CGFloat = 12
    /// 16 pt – between cards; a card's header and its content.
    static let cardGap: CGFloat = 16
    /// 20 pt – inside a card, and the screen's side margins.
    static let card: CGFloat = 20
    /// 24 pt – between groups inside a card (e.g. one scale and the next).
    static let group: CGFloat = 24
    /// 32 pt – after a screen's header, and below the last card.
    static let section: CGFloat = 32
}

/// Corner radii: cards, tiles and buttons inside them, open fields.
nonisolated enum Radius {
    static let card: CGFloat = 24
    static let tile: CGFloat = 16
    static let field: CGFloat = 14
}

/// How big things are to tap.
nonisolated enum TapSize {
    /// Every tap target: at least 44 × 44 pt.
    static let minimum: CGFloat = 44
    /// Primary actions, tiles and the track of a scale: about 56 pt.
    static let large: CGFloat = 56
}
