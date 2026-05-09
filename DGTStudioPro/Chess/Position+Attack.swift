//
//  Position+Attack.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/05/2026.
//

extension Position {
    
    /// Whether `square` is attacked by any piece of the given `attacker` color.
    internal func isSquareAttacked(_ square: Square, by attacker: PieceColor) -> Bool {
        // Pawn attacks: an enemy pawn one rank "in front of" us (from the attacker's
        // perspective) on either adjacent file would be attacking this square.
        let pawnFromOffsets: [Int] = attacker == .white ? [-7, -9] : [7, 9]
        let attackingPawn = Piece(attacker, .pawn)
        for offset in pawnFromOffsets {
            let from = square + offset
            guard from.isOnBoard else { continue }
            guard abs(from.file - square.file) == 1 else { continue }
            if self[from] == attackingPawn { return true }
        }
        
        // Knight attacks: any of the 8 knight-jump squares holds an enemy knight.
        let knightFromOffsets: [Int] = [17, 15, 10, 6, -6, -10, -15, -17]
        let attackingKnight = Piece(attacker, .knight)
        for offset in knightFromOffsets {
            let from = square + offset
            guard from.isOnBoard else { continue }
            guard abs(from.file - square.file) <= 2 else { continue }
            if self[from] == attackingKnight { return true }
        }
        
        // King attacks: any of the 8 neighbor squares holds an enemy king.
        let kingFromOffsets: [Int] = [1, 7, 8, 9, -1, -7, -8, -9]
        let attackingKing = Piece(attacker, .king)
        for offset in kingFromOffsets {
            let from = square + offset
            guard from.isOnBoard else { continue }
            guard abs(from.file - square.file) <= 1 else { continue }
            if self[from] == attackingKing { return true }
        }
        
        // Orthogonal sliders (rook, queen) — cast rays along ranks/files.
        for direction in [1, 8, -1, -8] {
            if rayHitsSlider(
                from: square, direction: direction,
                slider1: .rook, slider2: .queen,
                attacker: attacker
            ) { return true }
        }
        
        // Diagonal sliders (bishop, queen) — cast rays along diagonals.
        for direction in [7, 9, -7, -9] {
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
    private func rayHitsSlider(
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
