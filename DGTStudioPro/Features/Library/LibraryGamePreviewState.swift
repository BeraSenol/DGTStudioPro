import Foundation

/// The derived board state a Library preview renders: the position reached by
/// walking a game's SAN moves, plus the piece-identity tracker, the last move
/// (for the highlight), and the side-to-move's king square when in check.
///
/// A pure value type — it holds only chess-core values and is computed by
/// `compute(from:)`. `LibraryGamePreviewView` builds one from `game.moves` to
/// show a thumbnail of the final position without constructing a full `Game`.
///
/// The walk mirrors `Game`'s per-ply walk (`parseSAN` → `applyMove` →
/// `applying`), but is **non-throwing**: the first SAN that fails to parse
/// stops the walk and the state reached so far is returned, so a preview always
/// renders *something* (the last legal position) rather than failing. This is
/// the right tradeoff for a thumbnail — unlike `Game.init`, which throws on
/// corrupt data so the caller can surface a diagnostic.
internal struct LibraryGamePreviewState: Equatable {
    
    // MARK: Stored Properties
    
    /// Position after the (successfully parsed) moves.
    internal var position: Position
    
    /// Piece-identity tracker after the same moves, so the board view keeps
    /// stable identity across captures, promotions, and castling.
    internal var pieceTracker: PieceTracker
    
    /// The most recent successfully applied move, or `nil` if none were
    /// applied (empty list, or the first move failed to parse).
    internal var lastMove: LastMove?
    
    /// The side-to-move's king square when that side is in check; `nil`
    /// otherwise. Drives the king-in-check highlight.
    internal var checkSquare: Square?
    
    // MARK: Starting State
    
    /// The standard starting position with no moves played. Equivalent to
    /// `compute(from: [])` (and pinned to be so by the tests).
    internal static let starting = compute(from: [])
    
    // MARK: Computation
    
    /// Walks the SAN `moves` from the standard start, returning the state at
    /// the end of the walk.
    ///
    /// Non-throwing by design: parsing stops at the first move that fails (an
    /// unrecognised or illegal SAN), and the state after the last *successful*
    /// move is returned. An empty list yields the starting state.
    internal static func compute(from moves: [String]) -> LibraryGamePreviewState {
        var state: GameState = .starting
        var tracker: PieceTracker = .starting
        var lastMove: LastMove?
        
        for san in moves {
            guard let move = try? state.parseSAN(san) else { break }
            tracker.applyMove(move)
            state = state.applying(move)
            lastMove = LastMove(from: move.from, to: move.to)
        }
        
        let checkSquare = state.isInCheck
        ? state.position.kingSquare(for: state.activeColor)
        : nil
        
        return LibraryGamePreviewState(
            position: state.position,
            pieceTracker: tracker,
            lastMove: lastMove,
            checkSquare: checkSquare
        )
    }
}
