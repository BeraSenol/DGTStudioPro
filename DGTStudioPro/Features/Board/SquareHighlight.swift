internal struct SquareHighlight: OptionSet, Sendable {
    
    // MARK: Static Constants
    internal static let lastMove = SquareHighlight(rawValue: 1 << 0)
    internal static let check    = SquareHighlight(rawValue: 1 << 1)
    internal static let selected = SquareHighlight(rawValue: 1 << 2)
    /// Recovery (M6.1): something is on this square that shouldn't be — a
    /// stray or wrong piece. Deliberately generic: the views render a
    /// style; only `RecoveryGuidance` knows it means "remove/replace".
    internal static let attention = SquareHighlight(rawValue: 1 << 3)
    /// Recovery (M6.1): a piece belongs on this (empty) square.
    internal static let target    = SquareHighlight(rawValue: 1 << 4)
    
    // MARK: Stored Properties
    internal let rawValue: UInt8
}
