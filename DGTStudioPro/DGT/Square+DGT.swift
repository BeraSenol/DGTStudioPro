// DGT numbers fields a8 = 0 … h1 = 63 (protocol doc); the map is `(7 − rank)*8 + file` in both
// directions - it is its own inverse, which `SquareDGTFieldTests` pins by round-tripping all 64.
//
// A second `extension Square` is a second extension on every `Int` - see `Square.swift` for what
// the typealias costs. `Int(dgtField: 5)` compiles anywhere in the app.
extension Square {
    
    /// A DGT field index (a8 = 0 … h1 = 63) to an app `Square` (a1 = 0 … h8 = 63).
    ///
    /// **Nil rather than a trap**, because this is the wire boundary: a corrupt field byte has to
    /// surface as a decode failure. `DGTDecoder` is the only production caller.
    init?(dgtField field: Int) {
        guard UInt(bitPattern: field) < Square.count else { return nil }
        self = (7 - field / 8) * 8 + (field % 8)
    }
    
    /// The inverse - **test-only by decision** (waiver register); the app's outbound commands are
    /// fixed bytes. `assert` rather than a guard, because the input comes from app code, not the
    /// wire: the opposite trust from the initializer above.
    var dgtField: Int {
        assert(isOnBoard, "dgtField called on off-board square \(self)")
        return (7 - rank) * 8 + file
    }
}
