import Foundation

/// The derived board state a preview renders: position, tracker, last move, check square - a
/// pure value computed by walking SAN, the exact pairing the review board renders.
struct LibraryGamePreviewState: Equatable {
    
    // MARK: Stored Properties
    
    /// Position after the (successfully parsed) moves.
    var position: Position
    
    /// Piece-identity tracker after the same moves, so the board view keeps
    /// stable identity across captures, promotions, and castling.
    var pieceTracker: PieceTracker
    
    /// The most recent successfully applied move, or `nil` if none were
    /// applied (empty list, or the first move failed to parse).
    var lastMove: LastMove?
    
    /// The side-to-move's king square when that side is in check; `nil`
    /// otherwise. Drives the king-in-check highlight.
    var checkSquare: Square?
    
    // MARK: Starting State
    
    /// The standard starting position with no moves played. Equivalent to
    /// `compute(from: [])` (and pinned to be so by the tests).
    static let starting = compute(from: [])
    
    // MARK: Computation
    
    /// Walks `moves` from the standard start; an unparseable ply stops the walk at the last good state.
    static func compute(from moves: [String]) -> LibraryGamePreviewState {
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
