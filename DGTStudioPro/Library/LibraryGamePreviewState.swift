//
//  LibraryGamePreviewState.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/05/2026.
//

/// Pre-computed state for `LibraryGamePreviewView`.
///
/// Walks a game's SAN move list once and bundles everything the static
/// preview needs to render: the final position, piece-identity tracker
/// (so promotion / castling preserve animation identity if the preview
/// is later wired into a scrubber), the last move played (for highlight),
/// and the check square (for the king highlight on mate positions).
///
/// Lives outside `Chess/` because `PieceTracker` is a UI-adjacent concern
/// (animation IDs don't matter to a headless Perft test). Combining it
/// with the chess-core walk in one struct avoids duplicating the parse +
/// apply loop in the view body.
internal struct LibraryGamePreviewState: Equatable {
    
    // MARK: Static Constants
    
    internal static let starting = LibraryGamePreviewState(
        position: .starting,
        pieceTracker: .starting,
        lastMove: nil,
        checkSquare: nil
    )
    
    // MARK: Stored Properties
    
    internal let position: Position
    internal let pieceTracker: PieceTracker
    internal let lastMove: LastMove?
    internal let checkSquare: Square?
    
    // MARK: Static Methods
    
    /// Walks `sanMoves` from the standard starting position, parsing and
    /// applying each move while tracking piece identities and the last move
    /// played.
    ///
    /// On the first SAN string that fails to parse (malformed game data,
    /// for instance), the walk stops gracefully and returns whatever was
    /// successfully replayed up to that point. The "strict" SAN policy
    /// applies to chess-rule fidelity, not to import-time UX — showing the
    /// player names plus a partial board is better than showing nothing.
    /// PGN-import-time validation is a separate concern (Future Enhancement).
    internal static func compute(from sanMoves: [String]) -> LibraryGamePreviewState {
        var state: GameState = .starting
        var tracker: PieceTracker = .starting
        var lastMove: LastMove? = nil
        
        for san in sanMoves {
            guard let move = try? state.parseSAN(san) else { break }
            tracker.applyMove(move)
            lastMove = LastMove(from: move.from, to: move.to)
            state = state.applying(move)
        }
        
        let checkSquare: Square? = state.isInCheck
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
