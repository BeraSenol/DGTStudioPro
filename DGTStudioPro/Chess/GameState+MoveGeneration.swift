//
//  GameState+MoveGeneration.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

extension GameState {
    
    // MARK: Entry Point
    internal func pseudoLegalMoves() -> [Move] {
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
    
    // MARK: Legal Move Filter (7c)
    
    /// Pseudo-legal moves filtered to remove any that leave the moving side's
    /// king in check.
    ///
    /// Performance note: the per-move legality check needs to know where the
    /// moving side's king is *after* the move, which would normally cost an
    /// O(64) board scan per pseudo-legal move (kiwipete generates ~48 pseudo-
    /// legal moves per node, so that's 3 KB of scans per call). We pay the
    /// scan once for the current king square here, then derive the post-move
    /// king square in `isLegal` without scanning: if the king itself moves
    /// (including castling), its new square is `move.to`; otherwise it stays
    /// put. Measurably cuts perft time, especially at depth 5.
    ///
    /// Defensive: a position without our king on the board has no legal moves
    /// (it's not a valid game state to play from), so we return an empty array.
    internal func legalMoves() -> [Move] {
        guard let currentKingSquare = position.kingSquare(for: activeColor) else {
            return []
        }
        return pseudoLegalMoves().filter { isLegal($0, currentKingSquare: currentKingSquare) }
    }
    
    /// Whether the moving side's king is currently attacked.
    internal var isInCheck: Bool {
        guard let kingSq = position.kingSquare(for: activeColor) else { return false }
        return position.isSquareAttacked(kingSq, by: activeColor.opponent)
    }
    
    /// In check with no legal moves.
    internal var isCheckmate: Bool {
        isInCheck && legalMoves().isEmpty
    }
    
    /// Not in check, but no legal moves.
    internal var isStalemate: Bool {
        !isInCheck && legalMoves().isEmpty
    }
    
    /// Apply the move to a hypothetical position and check whether the moving
    /// side's king is left attacked. This single check naturally handles pins,
    /// EP discovered checks, moving while in check, and king self-checks —
    /// no piece-specific reasoning required.
    ///
    /// `currentKingSquare` is the moving side's king square *before* the move.
    /// If the move is a king move (or castling — `pieceType == .king` is true
    /// for both), the post-move king square is `move.to`; otherwise the king
    /// hasn't moved and the cached square is still correct. Either way, no
    /// board scan is needed on the resulting position.
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
        let captureOffsets = color == .white ? [7, 9] : [-9, -7]
        
        // Single push (and double push, only from start rank, only if both squares empty)
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
        
        // Diagonal captures (regular + en passant)
        for offset in captureOffsets {
            let target = square + offset
            guard target.isOnBoard else { continue }
            // File-distance check rejects file wraparound
            // (a-pawn capturing "left" or h-pawn capturing "right").
            guard abs(target.file - square.file) == 1 else { continue }
            
            let targetPiece = position[target]
            
            if let targetType = targetPiece.type, targetPiece.color == color.opponent {
                // Regular capture (with promotion if landing on promotion rank)
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
                // En passant: target square is empty; captured pawn lives one rank back.
                // Move's capturedSquare computed property handles the offset.
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
    
    /// Non-sliding moves: one hop per offset, no ray. Knight and king differed
    /// only in their offset table, their file-distance bound, and the piece
    /// type stamped on the move — three parameters, not two functions.
    ///
    /// `maxFileDistance` is the wraparound guard and is *not* derivable from
    /// the offsets: a knight legitimately changes file by 2, a king never by
    /// more than 1, and both tables contain offsets that would wrap silently.
    ///
    /// Castling is not appended here. It stays at the `.king` case in
    /// `pseudoLegalMoves` so this function has no piece-specific arm at all,
    /// and so the emitted order is unchanged.
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
            
            // Walk the ray. Each step's file may change by at most 1 — anything
            // larger is a wraparound across the board edge.
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
    
    // MARK: Castling (7d)
    //
    // Castling has its own conditions because the king's *transit* square must
    // not be attacked — a constraint the legal filter alone cannot check, since
    // the filter only sees the king's final square. Destination-square safety
    // does fall out of the legal filter, so we don't repeat it here.
    private func appendCastlingMoves(from square: Square, into moves: inout [Move]) {
        let color = activeColor
        
        // Castling rights imply king is on its home square; defensively double-check.
        let homeSquare = color == .white ? Squares.e1 : Squares.e8
        guard square == homeSquare else { return }
        
        // Rights before the scan. With neither side available, both branches
        // below are dead and the out-of-check test can append nothing — and
        // that test is this function's expensive half. Most nodes in a deep
        // search have already spent both rights.
        guard castlingRights.has(color, .kingSide)
                || castlingRights.has(color, .queenSide) else { return }
        
        // Rights imply a rook on its home corner for any position reached
        // through `applying` — the revocation rules maintain that. They do
        // *not* imply it for a position parsed from a FEN, and the draft
        // sidecar resumes through `FEN(parsing:)`, so a hand-edited file can
        // hand us `KQ` with a bare back rank. Without this, `O-O` is generated
        // and `Position.applying` copies an empty square onto f1.
        // Free for perft: in a legal position the test is always true, so
        // neither the generated set nor its order changes.
        let homeRook = Piece(color, .rook)
        let kingSideRookHome:  Square = color == .white ? Squares.h1 : Squares.h8
        let queenSideRookHome: Square = color == .white ? Squares.a1 : Squares.a8
        
        // Cannot castle out of check.
        guard !position.isSquareAttacked(square, by: color.opponent) else { return }
        
        // Kingside
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
        
        // Queenside (b-file must be empty too — rook traverses it — but isn't part of the king's path)
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
