// DGT numbers fields a8 = 0 … h1 = 63 (protocol doc); the map is `(7 − rank)*8 + file` in both
// directions — its own inverse.
extension Square {
    
    /// Converts a DGT field index (a8 = 0 … h1 = 63) to an app `Square`
    /// (a1 = 0 … h8 = 63). Returns `nil` for out-of-range input so a corrupt
    /// field byte off the wire surfaces as a decode failure, not a crash.
    internal init?(dgtField field: Int) {
        guard UInt(bitPattern: field) < Square.count else { return nil }
        self = (7 - field / 8) * 8 + (field % 8)
    }
    
    /// The DGT field index — `init(dgtField:)`'s inverse. No production caller (commands are fixed
    /// bytes); test-only by decision.
    internal var dgtField: Int {
        assert(isOnBoard, "dgtField called on off-board square \(self)")
        return (7 - rank) * 8 + file
    }
}
