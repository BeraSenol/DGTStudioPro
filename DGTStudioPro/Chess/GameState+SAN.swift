import Foundation

extension GameState {
    
    // MARK: SAN Parser (7e)
    
    /// Parses SAN in this state's context, returning the matching legal move. Strict SAN: `x`
    /// present iff capture; pawn captures carry the source file; promotion in `=Q`, `(Q)`, bare `Q`.
    func parseSAN(_ san: String) throws(SANParseError) -> Move {
        var s = san.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { throw SANParseError.empty }
        
        // Drops all four suffixes; `PGNParser.stripAnnotations` keeps `+`/`#` — the app's two strippers
        // differ on purpose (the movetext validator turns on which is which).
        while let last = s.last, "+#!?".contains(last) {
            s.removeLast()
        }
        guard !s.isEmpty else { throw SANParseError.malformed(san) }
        
        // Castling: `O-O`/`0-0` both read; the serializer emits canonical `O-O`.
        if s == "O-O" || s == "0-0" {
            return try matchCastling(kingside: true, original: san)
        }
        if s == "O-O-O" || s == "0-0-0" {
            return try matchCastling(kingside: false, original: san)
        }
        
        let tokens = try Self.tokenize(s, original: san)
        return try matchMove(tokens, original: san)
    }
    
    // MARK: SAN Serializer (7f)
    
    /// Canonical SAN for a legal `move` in this state.
    func san(for move: Move) -> String {
        if move.isCastling {
            let castle = move.castlingSide == .kingSide ? "O-O" : "O-O-O"
            return castle + checkOrMateSuffix(after: move)
        }
        
        let piece = move.pieceType.notation               // "" for pawn, NBRQK otherwise
        let disamb = disambiguator(for: move)
        let capture = move.isCapture ? "x" : ""
        let target = move.to.algebraicNotation
        let promo = move.promotionType.map { "=\($0.notation)" } ?? ""
        let suffix = checkOrMateSuffix(after: move)
        
        return piece + disamb + capture + target + promo + suffix
    }
    
    // MARK: Match Helpers (parser)
    
    private func matchMove(_ tokens: SANTokens, original: String) throws(SANParseError) -> Move {
        let candidates = legalMoves().filter { move in
            if move.pieceType != tokens.pieceType { return false }
            if move.to != tokens.toSquare { return false }
            if move.promotionType != tokens.promotion { return false }
            if move.isCapture != tokens.isCapture { return false }
            if let f = tokens.fromFile, move.from.file != f { return false }
            if let r = tokens.fromRank, move.from.rank != r { return false }
            return true
        }
        
        return try Self.unique(candidates, original: original)
    }
    
    private func matchCastling(kingside: Bool, original: String) throws(SANParseError) -> Move {
        let destinationFile = (kingside ? CastlingSide.kingSide : .queenSide).kingDestinationFile
        let candidates = legalMoves().filter {
            $0.isCastling && $0.to.file == destinationFile
        }
        return try Self.unique(candidates, original: original)
    }
    
    /// Zero matches = parse failure, one = answer, more = ambiguity — both matchers ended in this
    /// exact switch, free to drift.
    private static func unique(
        _ candidates: [Move], original: String
    ) throws(SANParseError) -> Move {
        switch candidates.count {
        case 0:  throw SANParseError.noMatchingMove(original)
        case 1:  return candidates[0]
        default: throw SANParseError.ambiguous(original, count: candidates.count)
        }
    }
    
    // MARK: Disambiguation (serializer)
    
    /// FIDE preference order: file → rank → both.
    private func disambiguator(for move: Move) -> String {
        // Pawn captures always carry the file letter; pushes never.
        if move.pieceType == .pawn {
            return move.isCapture ? String(move.from.fileIndicator) : ""
        }
        
        let others = legalMoves().filter {
            $0 != move
            && $0.pieceType == move.pieceType
            && $0.to == move.to
        }
        
        if others.isEmpty { return "" }
        
        let conflictOnFile = others.contains { $0.from.file == move.from.file }
        let conflictOnRank = others.contains { $0.from.rank == move.from.rank }
        
        // No file conflict → file letter alone is unique. (FIDE first preference.)
        if !conflictOnFile {
            return String(move.from.fileIndicator)
        }
        // File conflicts but rank doesn't → rank digit alone is unique.
        if !conflictOnRank {
            return String(move.from.rankIndicator)
        }
        // Both conflict (rare; needs ≥3 attackers, e.g. promoted-piece scenarios).
        return move.from.algebraicNotation
    }
    
    // MARK: Check / Mate Suffix (serializer)
    
    private func checkOrMateSuffix(after move: Move) -> String {
        let next = applying(move)
        // `isCheckmate` recomputes `isInCheck` (two full scans). Ask once; pay `legalMoves()` only when
        // there is a check to resolve — every serialized ply pays this.
        guard next.isInCheck else { return "" }
        return next.legalMoves().isEmpty ? "#" : "+"
    }
    
    // MARK: Tokenization (parser)
    
    /// Back-to-front tokenizer over cleaned SAN — the target square is always the trailing information.
    private static func tokenize(_ input: String, original: String) throws(SANParseError) -> SANTokens {
        var s = input
        
        // Promotion, most specific first: `(X)`, `=X`, bare trailing letter (unambiguous — non-promotion
        // SAN ends in a rank digit).
        var promotion: PieceType? = nil
        
        if s.hasSuffix(")") {
            let chars = Array(s)
            let n = chars.count
            guard n >= 4, chars[n - 3] == "(",
                  let promo = promotionPieceType(from: chars[n - 2]) else {
                throw SANParseError.malformed(original)
            }
            promotion = promo
            s = String(chars[0 ..< (n - 3)])
        } else {
            let chars = Array(s)
            let n = chars.count
            if n >= 2, chars[n - 2] == "=" {
                guard let promo = promotionPieceType(from: chars[n - 1]) else {
                    throw SANParseError.malformed(original)
                }
                promotion = promo
                s = String(chars[0 ..< (n - 2)])
            } else if let last = chars.last, let promo = promotionPieceType(from: last) {
                promotion = promo
                s = String(s.dropLast())
            }
        }
        
        // -- Target square ----------------------------------------------------
        guard s.count >= 2 else { throw SANParseError.malformed(original) }
        let targetStr = String(s.suffix(2))
        guard let toSquare = Square.fromAlgebraicNotation(targetStr) else {
            throw SANParseError.malformed(original)
        }
        s = String(s.dropLast(2))
        
        // -- Capture marker ---------------------------------------------------
        var isCapture = false
        if s.hasSuffix("x") {
            isCapture = true
            s = String(s.dropLast())
        }
        
        // -- Leading piece letter (optional; absence ⇒ pawn) ------------------
        var pieceType: PieceType = .pawn
        if let first = s.first, let piece = pieceTypeFromSANLetter(first) {
            pieceType = piece
            s = String(s.dropFirst())
        }
        
        // -- Disambiguator (0–2 remaining chars: file, rank, or file+rank) ----
        var fromFile: Int? = nil
        var fromRank: Int? = nil
        let disambiguator = Array(s)
        switch disambiguator.count {
        case 0:
            break
        case 1:
            let c = disambiguator[0]
            if let file = Square.file(from: c) {
                fromFile = file
            } else if let rank = Square.rank(from: c) {
                fromRank = rank
            } else {
                throw SANParseError.malformed(original)
            }
        case 2:
            guard let file = Square.file(from: disambiguator[0]),
                  let rank = Square.rank(from: disambiguator[1]) else {
                throw SANParseError.malformed(original)
            }
            fromFile = file
            fromRank = rank
        default:
            throw SANParseError.malformed(original)
        }
        
        // -- Cross-field validity --------------------------------------------
        if promotion != nil, pieceType != .pawn {
            throw SANParseError.malformed(original)
        }
        if pieceType == .pawn, isCapture, fromFile == nil {
            throw SANParseError.malformed(original)
        }
        
        return SANTokens(
            pieceType: pieceType,
            fromFile: fromFile,
            fromRank: fromRank,
            toSquare: toSquare,
            isCapture: isCapture,
            promotion: promotion
        )
    }
    
    // MARK: Character Helpers
    
    private static func pieceTypeFromSANLetter(_ c: Character) -> PieceType? {
        switch c {
        case "N": return .knight
        case "B": return .bishop
        case "R": return .rook
        case "Q": return .queen
        case "K": return .king
        default:  return nil
        }
    }
    
    private static func promotionPieceType(from c: Character) -> PieceType? {
        switch c {
        case "Q": return .queen
        case "R": return .rook
        case "B": return .bishop
        case "N": return .knight
        default:  return nil
        }
    }
}

// MARK: FEN Forwarding

extension FEN {
    func parseSAN(_ san: String) throws(SANParseError) -> Move {
        try GameState(self).parseSAN(san)
    }
    
    func san(for move: Move) -> String {
        GameState(self).san(for: move)
    }
}

// MARK: SAN Tokens

/// Parsed SAN components, prior to legal-move matching.
private struct SANTokens {
    let pieceType: PieceType
    let fromFile: Int?
    let fromRank: Int?
    let toSquare: Square
    let isCapture: Bool
    let promotion: PieceType?
}

// MARK: Errors

enum SANParseError: Error, Equatable {
    /// SAN string was empty or whitespace-only.
    case empty
    /// SAN string didn't match the syntactic shape of a move.
    case malformed(String)
    /// SAN parsed correctly but no legal move in the current position matches.
    case noMatchingMove(String)
    /// SAN matches more than one legal move (caller should add a disambiguator).
    case ambiguous(String, count: Int)
}
