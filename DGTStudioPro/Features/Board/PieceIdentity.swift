/// One rendered piece: what, where, and the identity it animates under (M6's currency).
/// The layer keys its `ForEach` on `key` - a persisting key glides, a churned key fades; there
/// is no third behaviour, because an unproven piece never gets a key that can persist.
struct ResolvedPiece: Equatable, Hashable, Sendable, Identifiable {
    
    /// A proven tracker identity or a square-bound anonymous one. `anonymous` carries the `Piece`
    /// too: a replaced occupant must produce a fresh key (a fade, never a morph - morphing is
    /// promotion's grammar alone).
    ///
    /// Promotion morphs because the key does *not* change: `placements(for:)` lands the promoted
    /// piece under the pawn's identity, so `key` persists while `piece` differs, and the layer's
    /// `ForEach` cross-fades one glyph in place rather than swapping two.
    enum Key: Equatable, Hashable, Sendable {
        case tracked(PieceID)
        case anonymous(Square, Piece)
    }
    
    let key: Key
    let piece: Piece
    let square: Square
    
    var id: Key { key }
}

/// Resolves every rendered piece's identity. **Output occupancy is the rendered position
/// verbatim, always** - the resolver decides keys, never presence (the mirror invariant as a
/// pure function, pinned across every fixture). Identity is proven or absent, never guessed:
/// parity per square, then the reconstructor's own verified move, then anonymous.
enum PieceIdentity {
    
    /// The review arm: parity is total, the per-ply tracker vouches for every square. An `.empty`
    /// tracker degrades to all-anonymous (what style previews pass).
    static func resolved(
        position: Position,
        tracker: PieceTracker
    ) -> [ResolvedPiece] {
        Square.all.compactMap { square in
            let piece = position[square]
            guard piece.isOccupied else { return nil }
            let key: ResolvedPiece.Key =
            tracker[square].map(ResolvedPiece.Key.tracked)
            ?? .anonymous(square, piece)
            return ResolvedPiece(key: key, piece: piece, square: square)
        }
    }
    
    /// The mirror arm; nil game/tracker means all anonymous, nothing glides - the pre-M6 mirror exactly.
    static func resolved(
        physical: Position,
        game: GameState?,
        tracker: PieceTracker?
    ) -> [ResolvedPiece] {
        guard let game, let tracker else {
            return resolved(position: physical, tracker: .empty)
        }
        
        // Source 2, computed once per resolve - only consulted for squares parity couldn't explain.
        let proven = provenPlacements(game: game, physical: physical)
        
        return Square.all.compactMap { square in
            let piece = physical[square]
            guard piece.isOccupied else { return nil }
            
            let key: ResolvedPiece.Key
            if game.position[square] == piece, let identity = tracker[square] {
                key = .tracked(identity)
                // The second `let identity` is the "proven or absent" rule enforced: a proven arrival
                // whose *origin* the tracker cannot name falls through to anonymous rather than
                // borrowing one. Nothing here invents an identity.
            } else if let placement = proven.first(where: {
                $0.square == square && $0.piece == piece
            }), let identity = tracker[placement.origin] {
                key = .tracked(identity)
            } else {
                key = .anonymous(square, piece)
            }
            return ResolvedPiece(key: key, piece: piece, square: square)
        }
    }
    
    // MARK: Private Helpers
    
    /// A square the reconstructor proved an arrival on; the origin carries the identity.
    private struct Placement {
        let square: Square
        let piece: Piece
        let origin: Square
    }
    
    /// The landing squares a recognized move explains, across **all six** reconstruction cases -
    /// exhaustive on purpose, so a seventh is a compile error here rather than a silent fade.
    ///
    /// Proving: `.move`, `.correctable`, and `.castlingInProgress` - that last one is why a
    /// mid-gesture king glides to g1 while the rook still sits at home on parity. Not proving:
    /// `.noChange`, `.inProgress`, `.unresolved` - mid-thought and mid-desync get parity and
    /// anonymity only, because the reconstructor has not verified a whole position.
    private static func provenPlacements(
        game: GameState,
        physical: Position
    ) -> [Placement] {
        switch DGTReconstructor.reconstruct(from: game, physical: physical) {
        case .move(let move), .castlingInProgress(let move),
                .correctable(let move, _, _):
            return placements(for: move)
        case .noChange, .inProgress, .unresolved:
            return []
        }
    }
    
    /// The move's landing square - promotion lands the promoted piece under the pawn's identity
    /// (`PieceTracker.applyMove`'s rule) - plus the rook's for a castle.
    private static func placements(for move: Move) -> [Placement] {
        var result = [
            Placement(
                square: move.to,
                piece: Piece(move.pieceColor, move.promotionType ?? move.pieceType),
                origin: move.from
            )
        ]
        if move.isCastling, let rookFrom = move.rookFrom, let rookTo = move.rookTo {
            result.append(
                Placement(
                    square: rookTo,
                    piece: Piece(move.pieceColor, .rook),
                    origin: rookFrom
                )
            )
        }
        return result
    }
}
