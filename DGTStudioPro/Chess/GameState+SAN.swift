//
//  GameState+SAN.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/05/2026.
//

import Foundation

extension GameState {
    
    // MARK: SAN Parser (7e)
    
    /// Parses a Standard Algebraic Notation move string in the context of this
    /// game state and returns the matching legal `Move`.
    ///
    /// Strict SAN: the capture marker `x` must be present iff the move is a
    /// capture, and pawn captures must include the source-file disambiguator
    /// (e.g. `exd5`, never `xd5`). Promotion is accepted in three notations
    /// on read — `e8=Q`, `e8Q`, and `e8(Q)` — and the serializer (7f) emits
    /// the canonical `e8=Q`. Trailing `+`, `#`, `!`, `?` are stripped
    /// permissively before parsing.
    ///
    /// Errors are surfaced via `SANParseError`; callers building a per-game
    /// importer (Phase 7g) wrap these to add move-index context.
    internal func parseSAN(_ san: String) throws -> Move {
        var s = san.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { throw SANParseError.empty }
        
        // Strip trailing check / mate / annotation suffixes.
        while let last = s.last, last == "+" || last == "#" || last == "!" || last == "?" {
            s.removeLast()
        }
        guard !s.isEmpty else { throw SANParseError.malformed(san) }
        
        // Castling literals. Both `O-O`/`O-O-O` (FIDE) and `0-0`/`0-0-0`
        // (older PGN) are accepted on read; the serializer emits canonical
        // `O-O` / `O-O-O`.
        if s == "O-O" || s == "0-0" {
            return try matchCastling(kingside: true, original: san)
        }
        if s == "O-O-O" || s == "0-0-0" {
            return try matchCastling(kingside: false, original: san)
        }
        
        let tokens = try Self.tokenize(s, original: san)
        return try matchMove(tokens, original: san)
    }
    
    // MARK: Match Helpers
    
    /// Filter `legalMoves()` against the SAN-derived constraints.
    /// Zero matches → `noMatchingMove`. Multiple → `ambiguous` (caller is
    /// expected to add a disambiguator).
    private func matchMove(_ tokens: SANTokens, original: String) throws -> Move {
        let candidates = legalMoves().filter { move in
            if move.pieceType != tokens.pieceType { return false }
            if move.to != tokens.toSquare { return false }
            // Strict promotion equality: nil ↔ nil, .queen ↔ .queen, etc.
            if move.promotionType != tokens.promotion { return false }
            // Strict capture marker: `x` ↔ capture (handles EP correctly via
            // Move.isCapture, which is true whenever capturedPieceType is set).
            if move.isCapture != tokens.isCapture { return false }
            if let f = tokens.fromFile, move.from.file != f { return false }
            if let r = tokens.fromRank, move.from.rank != r { return false }
            return true
        }
        
        switch candidates.count {
        case 0:  throw SANParseError.noMatchingMove(original)
        case 1:  return candidates[0]
        default: throw SANParseError.ambiguous(original, count: candidates.count)
        }
    }
    
    private func matchCastling(kingside: Bool, original: String) throws -> Move {
        // King's destination file: g (=6) for kingside, c (=2) for queenside.
        let destinationFile = kingside ? 6 : 2
        let candidates = legalMoves().filter {
            $0.isCastling && $0.to.file == destinationFile
        }
        switch candidates.count {
        case 0:  throw SANParseError.noMatchingMove(original)
        case 1:  return candidates[0]
        default: throw SANParseError.ambiguous(original, count: candidates.count)
        }
    }
    
    // MARK: Tokenization
    
    /// Pure string-state tokenizer. Splits an already-cleaned SAN string
    /// (no castling form, no trailing `+`/`#`/`!`/`?`) into syntactic
    /// components. Works back-to-front because the target square is always
    /// the trailing piece of information; everything before it is the
    /// optional piece letter, optional disambiguator, and optional `x`.
    private static func tokenize(_ input: String, original: String) throws -> SANTokens {
        var s = input
        
        // -- Promotion (three accepted forms) ---------------------------------
        // Try the most specific form first: parenthesized `(X)`. Then `=X`.
        // Finally bare trailing `X` — unambiguous because every non-promotion
        // SAN move ends in a rank digit, so a trailing `Q`/`R`/`B`/`N` can
        // only mean promotion.
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
            if let file = fileIndex(from: c) {
                fromFile = file
            } else if let rank = rankIndex(from: c) {
                fromRank = rank
            } else {
                throw SANParseError.malformed(original)
            }
        case 2:
            guard let file = fileIndex(from: disambiguator[0]),
                  let rank = rankIndex(from: disambiguator[1]) else {
                throw SANParseError.malformed(original)
            }
            fromFile = file
            fromRank = rank
        default:
            throw SANParseError.malformed(original)
        }
        
        // -- Cross-field validity --------------------------------------------
        // Promotion is only meaningful on pawn moves.
        if promotion != nil, pieceType != .pawn {
            throw SANParseError.malformed(original)
        }
        // Strict SAN: pawn captures must specify the source file (`exd5`,
        // never `xd5`). Non-capture pawn moves never carry a disambiguator.
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
    
    private static func fileIndex(from c: Character) -> Int? {
        guard let v = c.asciiValue else { return nil }
        let index = Int(v) - Int(UInt8(ascii: "a"))
        return (0 ..< 8).contains(index) ? index : nil
    }
    
    private static func rankIndex(from c: Character) -> Int? {
        guard let v = c.asciiValue else { return nil }
        let index = Int(v) - Int(UInt8(ascii: "1"))
        return (0 ..< 8).contains(index) ? index : nil
    }
}

// MARK: - FEN Forwarding

extension FEN {
    internal func parseSAN(_ san: String) throws -> Move {
        try GameState(self).parseSAN(san)
    }
}

// MARK: - SAN Tokens

/// Parsed components of a SAN move, prior to legal-move matching.
/// Private to this file: it's an implementation detail of `parseSAN`.
private struct SANTokens {
    let pieceType: PieceType
    let fromFile: Int?
    let fromRank: Int?
    let toSquare: Square
    let isCapture: Bool
    let promotion: PieceType?
}

// MARK: - Errors

internal enum SANParseError: Error, Equatable {
    /// SAN string was empty or whitespace-only.
    case empty
    /// SAN string didn't match the syntactic shape of a move.
    case malformed(String)
    /// SAN parsed correctly but no legal move in the current position matches.
    case noMatchingMove(String)
    /// SAN matches more than one legal move (caller should add a disambiguator).
    case ambiguous(String, count: Int)
}
