//
//  GameState+MoveGeneration.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

//
//  GameState+MoveGeneration.swift
//  DGTStudioPro
//
//  Phase 7a — pseudo-legal move generation. Pawns shipped first; other piece
//  types follow in subsequent deliverables. Legal filtering (7c) and SAN
//  (7e/7f) live in their own files.
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
                appendPseudoLegalKnightMoves(from: square, into: &moves)
            case .bishop:
                appendPseudoLegalSlidingMoves(
                    from: square, pieceType: .bishop,
                    directions: [7, 9, -7, -9],
                    into: &moves
                )
            case .rook:
                appendPseudoLegalSlidingMoves(
                    from: square, pieceType: .rook,
                    directions: [1, 8, -1, -8],
                    into: &moves
                )
            case .queen:
                appendPseudoLegalSlidingMoves(
                    from: square, pieceType: .queen,
                    directions: [1, 7, 8, 9, -1, -7, -8, -9],
                    into: &moves
                )
            case .king:
                appendPseudoLegalKingMoves(from: square, into: &moves)
            }
        }
        
        return moves
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
        for promotion: PieceType in [.queen, .rook, .bishop, .knight] {
            moves.append(Move.make(
                from: from, to: to,
                pieceType: .pawn, pieceColor: color,
                capturedPieceType: capturedPieceType,
                promotionType: promotion
            ))
        }
    }
    
    // MARK: Knight Moves
    private func appendPseudoLegalKnightMoves(from square: Square, into moves: inout [Move]) {
        let color = activeColor
        let offsets: [Int] = [17, 15, 10, 6, -6, -10, -15, -17]
        
        for offset in offsets {
            let target = square + offset
            guard target.isOnBoard else { continue }
            // Knight jumps change file by 1 or 2; anything more is a wraparound.
            guard abs(target.file - square.file) <= 2 else { continue }
            
            let targetPiece = position[target]
            if let targetType = targetPiece.type {
                guard targetPiece.color == color.opponent else { continue }
                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: .knight, pieceColor: color,
                    capturedPieceType: targetType
                ))
            } else {
                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: .knight, pieceColor: color
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
    
    // MARK: King Moves (non-castling — castling lands in Phase 7d)
    private func appendPseudoLegalKingMoves(from square: Square, into moves: inout [Move]) {
        let color = activeColor
        let offsets: [Int] = [1, 7, 8, 9, -1, -7, -8, -9]
        
        for offset in offsets {
            let target = square + offset
            guard target.isOnBoard else { continue }
            // King steps change file by at most 1; anything more is a wraparound.
            guard abs(target.file - square.file) <= 1 else { continue }
            
            let targetPiece = position[target]
            if let targetType = targetPiece.type {
                guard targetPiece.color == color.opponent else { continue }
                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: .king, pieceColor: color,
                    capturedPieceType: targetType
                ))
            } else {
                moves.append(Move.make(
                    from: square, to: target,
                    pieceType: .king, pieceColor: color
                ))
            }
        }
    }
}
