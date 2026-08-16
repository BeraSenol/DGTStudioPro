struct SquareHighlight: OptionSet, Sendable {
    
    // MARK: Static Constants
    static let lastMove = SquareHighlight(rawValue: 1 << 0)
    static let check    = SquareHighlight(rawValue: 1 << 1)
    static let selected = SquareHighlight(rawValue: 1 << 2)
    /// Recovery (M6.1): something is on this square that shouldn't be - a
    /// stray or wrong piece. Deliberately generic: the views render a
    /// style; only `RecoveryGuidance` knows it means "remove/replace".
    static let attention = SquareHighlight(rawValue: 1 << 3)
    /// Recovery (M6.1): a piece belongs on this (empty) square.
    static let target    = SquareHighlight(rawValue: 1 << 4)
    /// A legal destination of the one lifted piece (`MoveHints`, 16 Aug 2026): a translucent
    /// dot on an empty square, a ring around an occupied one. The views render a style; only
    /// `MoveHints` knows it means "this piece may land here".
    static let hint      = SquareHighlight(rawValue: 1 << 5)
    
    // MARK: Stored Properties
    let rawValue: UInt8
}
