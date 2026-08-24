extension GameState {

    // MARK: Entry Point

    /// **The emission order is observable and pinned.** Perft counts leaves, so they are
    /// order-independent and will stay green through a reordering; what fails instead is
    /// `LegalMoveFilterTests`' three `.first` assertions. Re-run both before trusting a change here.
    func pseudoLegalMoves() -> [Move] {
        var moves: [Move] = []
        moves.reserveCapacity(48)

        for square in Square.all {
            let piece = position[square]
            guard piece.isColor(activeColor), let type = piece.type else { continue }

            switch type {
            case .pawn:
                appendPseudoLegalPawnMoves(from: square, into: &moves)
            case .knight:
                appendPseudoLegalStepMoves(
                    from: square, pieceType: .knight,
                    offsets: Square.knightOffsets, maxFileDistance: 2,
                    into: &moves
                )
            case .bishop:
                appendPseudoLegalSlidingMoves(
                    from: square, pieceType: .bishop,
                    directions: Square.bishopDirections,
                    into: &moves
                )
            case .rook:
                appendPseudoLegalSlidingMoves(
                    from: square, pieceType: .rook,
                    directions: Square.rookDirections,
                    into: &moves
                )
            case .queen:
                appendPseudoLegalSlidingMoves(
                    from: square, pieceType: .queen,
                    directions: Square.queenDirections,
                    into: &moves
                )
            case .king:
                appendPseudoLegalStepMoves(
                    from: square, pieceType: .king,
                    offsets: Square.kingOffsets, maxFileDistance: 1,
                    into: &moves
                )
                appendCastlingMoves(from: square, into: &moves)
            }
        }

        return moves
    }

    // MARK: Legal Move Filter

    /// Pseudo-legal filtered so no move leaves the mover's king attacked. A kingless side (hand-
    /// edited state) returns an empty array rather than trapping.
    func legalMoves() -> [Move] {
        guard let currentKingSquare = position.kingSquare(for: activeColor) else {
            return []
        }
        return pseudoLegalMoves().filter { isLegal($0, currentKingSquare: currentKingSquare) }
    }

    var isInCheck: Bool {
        guard let kingSq = position.kingSquare(for: activeColor) else { return false }
        return position.isSquareAttacked(kingSq, by: activeColor.opponent)
    }

    var isCheckmate: Bool {
        isInCheck && legalMoves().isEmpty
    }

    var isStalemate: Bool {
        !isInCheck && legalMoves().isEmpty
    }

    /// Apply hypothetically and test the king - one check that naturally covers pins, EP discovered
    /// checks, moving while in check, and king self-checks.
    private func isLegal(_ move: Move, currentKingSquare: Square) -> Bool {
        let nextKingSquare = move.pieceType == .king ? move.to : currentKingSquare
        let next = position.applying(move)
        return !next.isSquareAttacked(nextKingSquare, by: activeColor.opponent)
    }

    // MARK: Pawn Moves
    private func appendPseudoLegalPawnMoves(from square: Square, into moves: inout [Move]) {
        let color = activeColor
        let direction      = color == .white ? 8 : -8
        let startRank      = color == .white ? 1 : 6
        let promotionRank  = color == .white ? 7 : 0
        // The one offset table not `static` on `Square` - a fresh array per pawn per call. On the
        // deferred-cost census; hoisting it is mechanical but re-runs the perft gate.
        let captureOffsets = color == .white ? [7, 9] : [-9, -7]

        // Single push; double only from the start rank with both squares empty - which the nesting,
        // not a second occupancy test, is what guarantees.
        let oneStep = square + direction
        if oneStep.isOnBoard && !position[oneStep].isOccupied {
            if oneStep.rank == promotionRank {
                appendPromotions(
                    from: square, to: oneStep,
                    capturedPieceType: nil,
                    color: color,
                    into: &moves
                )
            } else {
                moves.append(Move.make(
                    from: square, to: oneStep,
                    pieceType: .pawn, pieceColor: color
                ))

                if square.rank == startRank {
                    let twoStep = square + 2 * direction
                    if !position[twoStep].isOccupied {
                        moves.append(Move.make(
                            from: square, to: twoStep,
                            pieceType: .pawn, pieceColor: color,
                            isDoublePawnPush: true
                        ))
                    }
                }
            }
        }

        for offset in captureOffsets {
            let target = square + offset
            guard target.isOnBoard else { continue }
            // File-distance check rejects wraparound (a-pawn capturing "left").
            guard abs(target.file - square.file) == 1 else { continue }

            let targetPiece = position[target]

            if let targetType = targetPiece.type, targetPiece.color == color.opponent {
                if target.rank == promotionRank {
                    appendPromotions(
                        from: square, to: target,
                        capturedPieceType: targetType,
                        color: color,
                        into: &moves
                    )
                } else {
                    moves.append(Move.make(
                        from: square, to: target,
                        pieceType: .pawn, pieceColor: color,
                        capturedPieceType: targetType
                    ))
                }
            } else if target == enPassantTarget {
                // En passant: the target square is empty; `capturedSquare` handles the offset. The
                // horizontal discovered check it can expose is caught by `isLegal`, which tests the
                // king against the fully applied position rather than reasoning about the ray.
                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: .pawn, pieceColor: color,
                    capturedPieceType: .pawn,
                    isEnPassant: true
                ))
            }
        }
    }

    private func appendPromotions(
        from: Square,
        to: Square,
        capturedPieceType: PieceType?,
        color: PieceColor,
        into moves: inout [Move]
    ) {
        for promotion in PieceType.promotionTypes {
            moves.append(Move.make(
                from: from, to: to,
                pieceType: .pawn, pieceColor: color,
                capturedPieceType: capturedPieceType,
                promotionType: promotion
            ))
        }
    }

    // MARK: Step Moves (Knight / King)

    /// Knight and king differ only in offset table, file-distance bound, and stamped type.
    /// `maxFileDistance` is the wraparound guard and is NOT derivable from the offsets.
    /// Castling stays at the `.king` case so the emitted order is unchanged.
    private func appendPseudoLegalStepMoves(
        from square: Square,
        pieceType: PieceType,
        offsets: [Int],
        maxFileDistance: Int,
        into moves: inout [Move]
    ) {
        let color = activeColor

        for offset in offsets {
            let target = square + offset
            guard target.isOnBoard else { continue }
            guard abs(target.file - square.file) <= maxFileDistance else { continue }

            let targetPiece = position[target]
            if let targetType = targetPiece.type {
                guard targetPiece.color == color.opponent else { continue }
                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: pieceType, pieceColor: color,
                    capturedPieceType: targetType
                ))
            } else {
                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: pieceType, pieceColor: color
                ))
            }
        }
    }

    // MARK: Sliding Moves (Bishop / Rook / Queen)
    private func appendPseudoLegalSlidingMoves(
        from square: Square,
        pieceType: PieceType,
        directions: [Int],
        into moves: inout [Move]
    ) {
        let color = activeColor

        for direction in directions {
            var previous = square
            var target = square + direction

            // Each ray step's file may change by at most 1 - more is a wraparound.
            while target.isOnBoard && abs(target.file - previous.file) <= 1 {
                let targetPiece = position[target]

                if let targetType = targetPiece.type {
                    if targetPiece.color == color.opponent {
                        moves.append(Move.make(
                            from: square, to: target,
                            pieceType: pieceType, pieceColor: color,
                            capturedPieceType: targetType
                        ))
                    }
                    // Ray stops on any occupied square (own or enemy).
                    break
                }

                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: pieceType, pieceColor: color
                ))

                previous = target
                target += direction
            }
        }
    }

    // MARK: Castling
    // Own conditions because the king's *transit* square must not be attacked - the legal filter
    // only sees the final square. Destination safety falls out of the filter.
    private func appendCastlingMoves(from square: Square, into moves: inout [Move]) {
        let color = activeColor

        // Rights imply the king is home; defensively double-check.
        let homeSquare = color == .white ? Squares.e1 : Squares.e8
        guard square == homeSquare else { return }

        // Rights before the scan: the out-of-check test is the expensive half, and most deep-search
        // nodes have spent both rights.
        guard castlingRights.has(color, .kingSide)
                || castlingRights.has(color, .queenSide) else { return }

        // Rights imply a home rook for positions reached through `applying` - NOT for a parsed FEN,
        // and the draft sidecar resumes through `FEN(parsing:)`, so a hand-edited file reaches here.
        let homeRook = Piece(color, .rook)
        let kingSideRookHome:  Square = color == .white ? Squares.h1 : Squares.h8
        let queenSideRookHome: Square = color == .white ? Squares.a1 : Squares.a8

        // Cannot castle out of check.
        guard !position.isSquareAttacked(square, by: color.opponent) else { return }

        if castlingRights.has(color, .kingSide) {
            let f: Square = color == .white ? Squares.f1 : Squares.f8
            let g: Square = color == .white ? Squares.g1 : Squares.g8
            if position[kingSideRookHome] == homeRook
                && !position[f].isOccupied
                && !position[g].isOccupied
                && !position.isSquareAttacked(f, by: color.opponent) {
                moves.append(Move.make(
                    from: square, to: g,
                    pieceType: .king, pieceColor: color,
                    isCastling: true
                ))
            }
        }

        // Queenside: b-file must be empty too (rook traverses it) but is not part of the king's path,
        // so it is checked for occupancy and never for attack.
        if castlingRights.has(color, .queenSide) {
            let b: Square = color == .white ? Squares.b1 : Squares.b8
            let c: Square = color == .white ? Squares.c1 : Squares.c8
            let d: Square = color == .white ? Squares.d1 : Squares.d8
            if position[queenSideRookHome] == homeRook
                && !position[b].isOccupied
                && !position[c].isOccupied
                && !position[d].isOccupied
                && !position.isSquareAttacked(d, by: color.opponent) {
                moves.append(Move.make(
                    from: square, to: c,
                    pieceType: .king, pieceColor: color,
                    isCastling: true
                ))
            }
        }
    }
}
