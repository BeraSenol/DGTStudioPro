//
//  Position+Attack.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

extension Position {
    
    /// Whether any of `offsets`, stepped once from `square` and guarded
    /// against edge wrap, holds `piece`.
    ///
    /// The step-and-compare loop `isSquareAttacked` ran three times (pawn,
    /// knight, king) and `SpecialCheckmate.knightGivesCheck` a fourth — the
    /// same shape `GameState.appendPseudoLegalStepMoves` already parameterises
    /// on the generation side, for the same reason.
    ///
    /// `maxFileDistance` is the wraparound guard and is *not* derivable from
    /// the offsets: a knight legitimately changes file by 2, a king never by
    /// more than 1. Pawns pass 1 — their ±7/±9 offsets shift the file by
    /// exactly 1 or exactly 7, never 0, so the `<=` here and the `== 1` it
    /// replaces accept the same squares.
    internal func hasPiece(
        _ piece: Piece,
        steppingFrom square: Square,
        offsets: [Int],
        maxFileDistance: Int
    ) -> Bool {
        offsets.contains { offset in
            let from = square + offset
            return from.isOnBoard
            && abs(from.file - square.file) <= maxFileDistance
            && self[from] == piece
        }
    }
    
    /// Whether `square` is attacked by any piece of the given `attacker` color.
    internal func isSquareAttacked(_ square: Square, by attacker: PieceColor) -> Bool {
        // Pawn attacks: an enemy pawn one rank "in front of" us (from the attacker's
        // perspective) on either adjacent file would be attacking this square.
        let pawnFromOffsets: [Int] = attacker == .white ? [-7, -9] : [7, 9]
        if hasPiece(
            Piece(attacker, .pawn),
            steppingFrom: square, offsets: pawnFromOffsets, maxFileDistance: 1
        ) { return true }
        
        // Knight attacks: any of the 8 knight-jump squares holds an enemy knight.
        if hasPiece(
            Piece(attacker, .knight),
            steppingFrom: square, offsets: Square.knightOffsets, maxFileDistance: 2
        ) { return true }
        
        // King attacks: any of the 8 neighbor squares holds an enemy king.
        let attackingKing = Piece(attacker, .king)
        for offset in Square.kingOffsets {
            let from = square + offset
            guard from.isOnBoard else { continue }
            guard abs(from.file - square.file) <= 1 else { continue }
            if self[from] == attackingKing { return true }
        }
        
        // Orthogonal sliders (rook, queen) — cast rays along ranks/files.
        for direction in Square.rookDirections {
            if rayHitsSlider(
                from: square, direction: direction,
                slider1: .rook, slider2: .queen,
                attacker: attacker
            ) { return true }
        }
        
        // Diagonal sliders (bishop, queen) — cast rays along diagonals.
        for direction in Square.bishopDirections {
            if rayHitsSlider(
                from: square, direction: direction,
                slider1: .bishop, slider2: .queen,
                attacker: attacker
            ) { return true }
        }
        
        return false
    }
    
    /// Walks a ray from `square` in `direction`. Returns true iff the first
    /// occupied square holds an enemy piece whose type matches one of the
    /// two slider types provided. Friendly pieces, enemy non-sliders, and
    /// reaching the board edge all return false (and stop the ray).
    /// Internal, not private: `SpecialCheckmate.rankSliderGivesCheck` used to
    /// carry a second copy of this walk. One ray primitive, two callers.
    internal func rayHitsSlider(
        from square: Square,
        direction: Int,
        slider1: PieceType,
        slider2: PieceType,
        attacker: PieceColor
    ) -> Bool {
        var previous = square
        var target = square + direction
        
        while target.isOnBoard && abs(target.file - previous.file) <= 1 {
            let piece = self[target]
            if let type = piece.type {
                return piece.color == attacker && (type == slider1 || type == slider2)
            }
            previous = target
            target += direction
        }
        
        return false
    }
}
