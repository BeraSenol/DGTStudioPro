//
//  DGTReconstructor.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 26/05/2026.
//

/// The outcome of trying to explain a settled physical board against the last
/// known-legal game state.
internal enum DGTReconstruction: Equatable {
    /// The physical board matches the last legal position — nothing happened
    /// (e.g. a piece was lifted and put back).
    case noChange
    /// A single legal move fully explains the board. Commit it.
    case move(Move)
    /// The king has moved two squares but its rook hasn't moved yet — a castle
    /// is underway. The live model commits the king move and shows a ghost rook
    /// on the rook's destination until the real rook lands. (FIDE castling is
    /// "king first," and players often complete it in two distinct motions.)
    case castlingInProgress(Move)
    /// A legal move is recognized, but the board is one simple physical
    /// correction away from completing it — most commonly an en-passant capture
    /// whose taken pawn wasn't lifted (a very common casual-play slip, and one
    /// whose diff is indistinguishable from a plain pawn push until the
    /// `applying(...)` check fails). `clear` lists the square(s) the player must
    /// empty; `expectedAfter` is the position once they do. This is a gentle
    /// nudge, NOT a desync — recovery should not take over.
    case correctable(move: Move, clear: [Square], expectedAfter: Position)
    /// Pieces have been lifted but none placed yet — a move is in the player's
    /// hand. Keep waiting; this is NOT a desync.
    case inProgress
    /// The board has settled into a configuration that no single legal move
    /// produces — an illegal move or a fumble. Hand off to recovery (D6).
    case unresolved
}

/// Reconstructs chess moves from physical board states. Entirely pure: given
/// the last legal `GameState` and a settled physical `Position`, it returns a
/// classification with no side effects. The live model owns all mutable state
/// (the running game, the 300 ms quiescence timer that decides when a board is
/// "settled," the recovery flow) and drives this on each quiescence.
///
/// Legality is sourced **only** from the app's own `GameState.legalMoves()` —
/// never an engine. The resolver derives the move's `(from, to, promotion?)`
/// from the board diff and looks up the unique legal move with those
/// coordinates (the `(from,to,promotion)`-uniqueness invariant pinned by
/// `MoveFootprintTests` guarantees at most one), then verifies the candidate
/// *fully* reproduces the physical board via `applying(...)`. That verification
/// is what rejects fumbles, stray pieces, and partial diffs.
internal enum DGTReconstructor {

    // MARK: Coordinate Resolver

    /// The `(from, to, promotion?) → Move` resolver. Returns the unique legal
    /// move with these coordinates, or nil if none is legal. Relies on the
    /// uniqueness invariant in `MoveFootprintTests`.
    ///
    /// Public for tests and any caller that already has a known legal state;
    /// `reconstruct` doesn't go through it (it caches `legalMoves()` once and
    /// scans the cached list directly, to avoid regenerating the move list
    /// twice per quiescence).
    internal static func move(
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

    internal static func reconstruct(
        from lastLegal: GameState,
        physical: Position
    ) -> DGTReconstruction {
        let before = lastLegal.position
        if before == physical { return .noChange }

        let mover = lastLegal.activeColor
        let diff = DGTBoardDiff(from: before, to: physical)

        let vacatedByMover = diff.vacated.filter { $0.value.isColor(mover) }
        let placedByMover  = diff.placed.filter  { $0.value.isColor(mover) }

        // Compute the legal-move list once. Every step below consumes it, and
        // `legalMoves()` regenerates pseudo-legal + filters per call — the live
        // path runs this every 300 ms quiescence, so paying twice is wasted work.
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

        // 1b) Near-miss: a legal en-passant move is recognized by its endpoints,
        //     but the captured pawn wasn't physically lifted. The EP diff looks
        //     exactly like a plain pawn push (the captured pawn's square is
        //     unchanged), so step 1's `applying` check fails and we'd otherwise
        //     flag a desync. Instead, surface it as a correctable nudge.
        if let endpoints,
           let ep = legal.first(where: {
               $0.isEnPassant && $0.from == endpoints.from && $0.to == endpoints.to
           }),
           let captured = ep.capturedSquare {
            let expected = before.applying(ep)
            // The physical board would equal `expected` if the player had also
            // lifted the captured pawn; i.e. it equals `expected` with that one
            // square still holding the pawn it had in `before`.
            var withUncapturedPawn = expected
            withUncapturedPawn[captured] = before[captured]
            if physical == withUncapturedPawn {
                return .correctable(move: ep, clear: [captured], expectedAfter: expected)
            }
        }

        // 2) Castle in progress: king has moved two squares, rook not yet.
        for castling in legal where castling.isCastling {
            if kingOnlyApplied(castling, mover: mover, before: before) == physical {
                return .castlingInProgress(castling)
            }
        }

        // 3) Only removals → a piece (or pieces, e.g. attacker + captured) is
        //    in hand. A move is underway; wait rather than flag a desync.
        if diff.placed.isEmpty {
            return .inProgress
        }

        // 4) Settled, with placements that don't complete any legal move.
        return .unresolved
    }

    // MARK: Endpoints

    /// Derives the moving piece's `(from, to)` from the diff, or nil when the
    /// diff doesn't look like a single completed move.
    private static func moveEndpoints(
        vacatedByMover: [Square: Piece],
        placedByMover: [Square: Piece],
        mover: PieceColor,
        before: Position
    ) -> (from: Square, to: Square)? {
        // Completed castle: the king appears among both the vacated and the
        // placed squares (alongside the rook).
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

    /// The promoted piece type if this looks like a promotion (a pawn left
    /// `from` and a non-pawn of the mover's color sits on `to`), else nil.
    /// Underpromotion is assumed never to occur physically, so the detected
    /// piece is read directly (effectively always a queen).
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

    /// `before` with only the castle's king relocated (the rook left in place),
    /// used to detect the king-moved-but-rook-not interim state.
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
