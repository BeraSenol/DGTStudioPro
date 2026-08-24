/// The outcome of trying to explain a settled physical board against the last known-legal state.
enum DGTReconstruction: Equatable {
    /// The physical board matches the last legal position - nothing happened (e.g. a piece was
    /// lifted and put back).
    case noChange
    /// A single legal move fully explains the board. Commit it.
    case move(Move)
    /// A castle underway: part of the gesture has landed. The model ghosts the airborne piece;
    /// commit waits for completion.
    case castlingInProgress(Move)
    /// A legal move one physical correction away - the en-passant capture whose taken pawn wasn't
    /// lifted. A nudge, NOT a desync. `clear` is always exactly one square, from the single
    /// producer below; `expectedAfter` has no reader at all - both consumers destructure it away.
    case correctable(move: Move, clear: [Square], expectedAfter: Position)
    /// Pieces have been lifted but none placed yet - a move is in the player's hand. Keep waiting;
    /// this is NOT a desync.
    case inProgress
    /// The board settled into a configuration no single legal move produces - an illegal move or a
    /// fumble. Hand off to recovery (D6).
    ///
    /// **A pawn parked on the last rank lands here.** `legalMoves()` gives every back-rank pawn
    /// move a promotion type, so e7-e8 with a pawn sitting on e8 matches nothing: the player has
    /// to place the new piece before the settle can read the move.
    case unresolved
}

/// Reconstructs moves from physical board states. Entirely pure; the session owns all mutable
/// state. Legality comes **only** from `GameState.legalMoves()` - never an engine - and answers
/// only when exactly one legal move explains the whole board.
enum DGTReconstructor {
    
    // MARK: Coordinate Resolver
    
    /// `(from, to, promotion?) → Move`: the unique legal move, or nil - relies on the uniqueness
    /// invariant pinned by `MoveFootprintTests`. **Test-only**: `reconstruct` matches against its
    /// own `legal` array, and both callers are suites.
    static func move(
        from: Square,
        to: Square,
        promotion: PieceType?,
        in state: GameState
    ) -> Move? {
        state.legalMoves().first {
            $0.from == from && $0.to == to && $0.promotionType == promotion
        }
    }
    
    // MARK: Classification
    
    static func reconstruct(
        from lastLegal: GameState,
        physical: Position
    ) -> DGTReconstruction {
        let before = lastLegal.position
        if before == physical { return .noChange }
        
        let mover = lastLegal.activeColor
        let diff = DGTBoardDiff(from: before, to: physical)
        
        // 0) Only removals → a move is in the player's hand; wait. Hoisted above move generation -
        //    this settle fires most often and needs no legal-move walk.
        if diff.placed.isEmpty { return .inProgress }
        
        let vacatedByMover = diff.vacated.filter { $0.value.isColor(mover) }
        let placedByMover  = diff.placed.filter  { $0.value.isColor(mover) }
        
        // One `legalMoves()` for every step below - regenerating per step doubles the 300 ms path's work.
        let legal = lastLegal.legalMoves()
        
        // Endpoints are shared by steps 1 and 1b.
        let endpoints = moveEndpoints(
            vacatedByMover: vacatedByMover,
            placedByMover: placedByMover,
            mover: mover,
            before: before
        )
        
        // 1) Resolve a complete move from the diff's endpoints.
        if let endpoints {
            let promotion = promotionType(
                from: endpoints.from,
                to: endpoints.to,
                before: before,
                physical: physical
            )
            if let candidate = legal.first(where: {
                $0.from == endpoints.from
                && $0.to == endpoints.to
                && $0.promotionType == promotion
            }), before.applying(candidate) == physical {
                return .move(candidate)
            }
        }
        
        // 1b) En-passant near-miss: the EP diff looks exactly like a plain pawn push, so step 1's
        //     `applying` check fails - surface a correctable nudge instead of a desync.
        if let endpoints,
           let ep = legal.first(where: {
               $0.isEnPassant && $0.from == endpoints.from && $0.to == endpoints.to
           }),
           let captured = ep.capturedSquare {
            let expected = before.applying(ep)
            // Physical board == expected with that one square still holding its `before` pawn.
            var withUncapturedPawn = expected
            withUncapturedPawn[captured] = before[captured]
            if physical == withUncapturedPawn {
                return .correctable(move: ep, clear: [captured], expectedAfter: expected)
            }
        }
        
        // 2) Castle in progress. FIDE castling is king-first and usually two motions, so quiescence
        //    can fire mid-gesture. The three interims with something placed are checked here; the
        //    fourth - king lifted, nothing down - never reaches this far, because step 0 already
        //    returned `.inProgress`. Rook-first with the king untouched is deliberately absent:
        //    byte-identical to a completed legal rook move.
        for castling in legal where castling.isCastling {
            guard let rookFrom = castling.rookFrom else { continue }
            let kingMoved = kingOnlyApplied(castling, mover: mover, before: before)
            if physical == kingMoved {
                return .castlingInProgress(castling)                    // king landed, rook home
            }
            var rookInHand = kingMoved
            rookInHand[rookFrom] = .empty
            if physical == rookInHand {
                return .castlingInProgress(castling)                    // king landed, rook in hand
            }
            var kingInHand = before.applying(castling)
            kingInHand[castling.to] = .empty
            if physical == kingInHand {
                return .castlingInProgress(castling)                    // rook landed, king in hand
            }
        }
        
        // 3) Settled, with placements that don't complete any legal move.
        return .unresolved
    }
    
    // MARK: Endpoints
    
    /// The moving piece's `(from, to)` from the diff, or nil when it doesn't look like one move.
    private static func moveEndpoints(
        vacatedByMover: [Square: Piece],
        placedByMover: [Square: Piece],
        mover: PieceColor,
        before: Position
    ) -> (from: Square, to: Square)? {
        // A *completed* castle: the king appears in both maps. An interim castle has one vacate and
        // one place, so it takes the branch below, fails step 1's `applying` check, and reaches
        // step 2 - which is the only path that recognizes it.
        let king = Piece(mover, .king)
        if vacatedByMover.count >= 2,
           let kingFrom = vacatedByMover.first(where: { $0.value == king })?.key,
           let kingTo = placedByMover.first(where: { $0.value == king })?.key {
            return (kingFrom, kingTo)
        }
        
        // Single-piece move: normal, capture, en passant, or promotion.
        if vacatedByMover.count == 1, placedByMover.count == 1 {
            return (vacatedByMover.first!.key, placedByMover.first!.key)
        }
        
        return nil
    }
    
    /// The promotion type if a pawn left `from` and a non-pawn of the mover's colour sits on `to`.
    /// Read off the board, not assumed - under-promotions are legal.
    private static func promotionType(
        from: Square,
        to: Square,
        before: Position,
        physical: Position
    ) -> PieceType? {
        guard before[from].type == .pawn,
              let arrived = physical[to].type,
              arrived != .pawn else {
            return nil
        }
        return arrived
    }
    
    /// `before` with only the king relocated - detects the king-moved-rook-not interim.
    private static func kingOnlyApplied(
        _ castling: Move,
        mover: PieceColor,
        before: Position
    ) -> Position {
        var result = before
        result[castling.from] = .empty
        result[castling.to] = Piece(mover, .king)
        return result
    }
}
