extension Position {
    
    /// Whether any offset, stepped once and wrap-guarded, holds `piece`. `maxFileDistance` is NOT
    /// derivable from the offsets - a knight legitimately changes file by 2. Internal rather than
    /// private because `SpecialCheckmate` reads it.
    func hasPiece(
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
    
    /// Whether `square` is attacked by any piece of the given `attacker` colour.
    ///
    /// **All six attacker types, and the enumeration below is the whole safety argument** - a
    /// missing case is an illegal move the legality filter then waves through, visible only as a
    /// wrong result many plies later. The queen is deliberately checked twice, once with each
    /// slider pair.
    func isSquareAttacked(_ square: Square, by attacker: PieceColor) -> Bool {
        // Pawn attacks. The offsets run *backwards* from the attacked square, which
        // `Square.pawnAttackOrigins` owns - it is the one colour-dependent offset table.
        if hasPiece(
            Piece(attacker, .pawn),
            steppingFrom: square,
            offsets: Square.pawnAttackOrigins(of: attacker),
            maxFileDistance: 1
        ) { return true }
        
        // Knight attacks: any of the 8 knight-jump squares holds an enemy knight.
        if hasPiece(
            Piece(attacker, .knight),
            steppingFrom: square, offsets: Square.knightOffsets, maxFileDistance: 2
        ) { return true }
        
        // King attacks: any of the 8 neighbour squares holds an enemy king. Same predicate as
        // `hasPiece(attackingKing, offsets: Square.kingOffsets, maxFileDistance: 1)`, hand-rolled
        // with no reason on record - collapsible.
        let attackingKing = Piece(attacker, .king)
        for offset in Square.kingOffsets {
            let from = square + offset
            guard from.isOnBoard else { continue }
            guard abs(from.file - square.file) <= 1 else { continue }
            if self[from] == attackingKing { return true }
        }
        
        // Orthogonal sliders (rook, queen) - cast rays along ranks/files.
        for direction in Square.rookDirections {
            if rayHitsSlider(
                from: square, direction: direction,
                slider1: .rook, slider2: .queen,
                attacker: attacker
            ) { return true }
        }
        
        // Diagonal sliders (bishop, queen) - cast rays along diagonals.
        for direction in Square.bishopDirections {
            if rayHitsSlider(
                from: square, direction: direction,
                slider1: .bishop, slider2: .queen,
                attacker: attacker
            ) { return true }
        }
        
        return false
    }
    
    /// Walks a ray; true iff the **first occupied** square holds a matching enemy slider - so a
    /// blocker of either colour ends the ray, which is what makes this an attack test rather than
    /// a line-of-sight one. Internal because `SpecialCheckmate` reads it.
    func rayHitsSlider(
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
