/// Legal-destination hints for a lifted piece - the translucent dots a desktop chess GUI shows
/// on pickup, driven here by the physical board (16 Aug 2026, by request).
///
/// The mirror never guesses, and this doesn't: when the physical board is exactly the
/// game's committed position minus one piece, the *committed position* names the piece that
/// stood on the vacated square, and its legal destinations are a pure fold. Anything less
/// unambiguous - a second lift, a piece already placed, a board mid-correction, the pre-connect
/// empty board - hints nothing, because an overlay that could be wrong about the position it
/// decorates is exactly the speculation the mirror rule forbids. Same family as `RecoveryGuidance`:
/// view-computed, session-gated, pure.
enum MoveHints {

    /// Destinations of the one lifted piece; empty unless the lift is exactly one square.
    ///
    /// An opponent's piece lifted on your turn yields the empty set for free - `legalMoves()`
    /// has no moves from a square the side to move doesn't own, which also covers fiddling
    /// with captured stock beside the board.
    ///
    /// Cost is two tiers, not one: the 64-square diff runs on **every** render this is called from,
    /// and the move generation only while a single lift is outstanding. `BoardDestination` calls it
    /// once per live-mirror render, and only when no recovery guidance is up - the recovery
    /// overlays' "recompute per observable change" family, and user-paced either way.
    static func destinations(for game: GameState?, physical: Position) -> Set<Square> {
        guard let game else { return [] }

        let diff = DGTBoardDiff(from: game.position, to: physical)
        guard diff.placed.isEmpty,
              diff.vacated.count == 1,
              let origin = diff.vacated.keys.first
        else { return [] }

        return Set(game.legalMoves().filter { $0.from == origin }.map(\.to))
    }
}
