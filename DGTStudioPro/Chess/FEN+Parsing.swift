//
//  FEN+Parsing.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 14/05/2026.
//

extension FEN {
    
    // MARK: String Parsing (7P prerequisite)
    
    /// Parses a FEN string into a `FEN` value.
    ///
    /// Supports both the full six-field FEN
    /// (`<placement> <color> <castling> <ep> <halfmove> <fullmove>`) and the
    /// four-field EPD-style variant (omitting halfmove and fullmove), which
    /// is common in Perft reference suites and analysis tools. When the
    /// trailing fields are absent, `halfmoveClock` defaults to 0 and
    /// `fullmoveNumber` to 1.
    ///
    /// Strict on shape: malformed placement, unknown active-color characters,
    /// unknown castling-rights characters, and non-square EP targets all
    /// throw a typed `FENParseError`. Whitespace splitting is forgiving
    /// (multiple spaces and leading/trailing whitespace are tolerated).
    internal init(parsing string: String) throws {
        let fields = string.split(whereSeparator: { $0.isWhitespace })
        
        guard fields.count == 4 || fields.count == 6 else {
            throw FENParseError.wrongFieldCount(fields.count)
        }
        
        let position    = try Self.parsePlacement(String(fields[0]))
        let activeColor = try Self.parseActiveColor(String(fields[1]))
        let castling    = try Self.parseCastling(String(fields[2]))
        let enPassant   = try Self.parseEnPassant(String(fields[3]))
        
        let halfmove: Int
        let fullmove: Int
        if fields.count == 6 {
            halfmove = try Self.parseHalfmoveClock(String(fields[4]))
            fullmove = try Self.parseFullmoveNumber(String(fields[5]))
        } else {
            halfmove = 0
            fullmove = 1
        }
        
        self.init(
            position: position,
            activeColor: activeColor,
            castlingRights: castling,
            enPassantTarget: enPassant,
            halfmoveClock: halfmove,
            fullmoveNumber: fullmove
        )
    }
    
    // MARK: Per-Field Parsers
    
    /// Parses the piece-placement field into a `Position`.
    ///
    /// Ranks are slash-separated and ordered top-to-bottom: the first rank
    /// substring is rank 8, the last is rank 1. Within each rank, ASCII
    /// digits 1–8 represent runs of empty squares; letters represent pieces
    /// per the FEN convention (uppercase white, lowercase black). Each rank
    /// must total exactly 8 files.
    private static func parsePlacement(_ field: String) throws -> Position {
        let ranks = field.split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else {
            throw FENParseError.malformedPlacement(field)
        }
        
        var position = Position.empty
        
        // ranks[0] is rank 8 (top), ranks[7] is rank 1 (bottom).
        for (index, rankString) in ranks.enumerated() {
            let rank = 7 - index
            var file = 0
            
            for char in rankString {
                if let digit = char.wholeNumberValue, (1...8).contains(digit) {
                    file += digit
                    if file > 8 { throw FENParseError.malformedPlacement(field) }
                } else if let piece = pieceFromFENCharacter(char) {
                    guard file < 8 else {
                        throw FENParseError.malformedPlacement(field)
                    }
                    position[rank * 8 + file] = piece
                    file += 1
                } else {
                    throw FENParseError.malformedPlacement(field)
                }
            }
            
            guard file == 8 else { throw FENParseError.malformedPlacement(field) }
        }
        
        return position
    }
    
    /// Parses the active-color field. Accepts `w` (white) or `b` (black).
    private static func parseActiveColor(_ field: String) throws -> PieceColor {
        switch field {
        case "w": return .white
        case "b": return .black
        default:  throw FENParseError.malformedActiveColor(field)
        }
    }
    
    /// Parses the castling-rights field. Accepts `-` (no rights) or any
    /// non-repeating subset of `KQkq` in any order. Duplicate characters
    /// are rejected (strict-on-shape; the chess core's other parsers do
    /// the same).
    private static func parseCastling(_ field: String) throws -> CastlingRights {
        if field == "-" { return .none }
        
        var raw: UInt8 = 0
        var seen: Set<Character> = []
        
        for char in field {
            guard seen.insert(char).inserted else {
                throw FENParseError.malformedCastling(field)
            }
            
            switch char {
            case "K": raw |= CastlingRights.mask(for: .white, .kingSide).rawValue
            case "Q": raw |= CastlingRights.mask(for: .white, .queenSide).rawValue
            case "k": raw |= CastlingRights.mask(for: .black, .kingSide).rawValue
            case "q": raw |= CastlingRights.mask(for: .black, .queenSide).rawValue
            default:  throw FENParseError.malformedCastling(field)
            }
        }
        
        return CastlingRights(rawValue: raw)
    }
    
    /// Parses the en-passant target field. Accepts `-` (no EP target) or a
    /// square in algebraic notation. Does not validate that the square is on
    /// a plausible EP rank — that's a position-validity concern, not a parse
    /// concern.
    private static func parseEnPassant(_ field: String) throws -> Square? {
        if field == "-" { return nil }
        guard let square = Square.fromAlgebraicNotation(field) else {
            throw FENParseError.malformedEnPassant(field)
        }
        return square
    }
    
    /// Parses the halfmove clock. Must be a non-negative integer.
    private static func parseHalfmoveClock(_ field: String) throws -> Int {
        guard let value = Int(field), value >= 0 else {
            throw FENParseError.malformedInteger(field)
        }
        return value
    }
    
    /// Parses the fullmove number. Must be a positive integer (FEN spec
    /// requires fullmove ≥ 1; the starting position has fullmove 1).
    private static func parseFullmoveNumber(_ field: String) throws -> Int {
        guard let value = Int(field), value >= 1 else {
            throw FENParseError.malformedInteger(field)
        }
        return value
    }
    
    // MARK: Piece Character Mapping
    
    private static func pieceFromFENCharacter(_ char: Character) -> Piece? {
        switch char {
        case "P": return .whitePawn
        case "N": return .whiteKnight
        case "B": return .whiteBishop
        case "R": return .whiteRook
        case "Q": return .whiteQueen
        case "K": return .whiteKing
        case "p": return .blackPawn
        case "n": return .blackKnight
        case "b": return .blackBishop
        case "r": return .blackRook
        case "q": return .blackQueen
        case "k": return .blackKing
        default:  return nil
        }
    }
}

// MARK: - Errors

internal enum FENParseError: Error, Equatable {
    /// The FEN string did not contain 4 or 6 whitespace-separated fields.
    case wrongFieldCount(Int)
    /// The piece-placement field was malformed: wrong rank count, file
    /// total not equal to 8 on some rank, unknown piece character, or
    /// invalid digit.
    case malformedPlacement(String)
    /// The active-color field was not `w` or `b`.
    case malformedActiveColor(String)
    /// The castling-rights field contained a character outside `-KQkq` or
    /// a duplicate right.
    case malformedCastling(String)
    /// The en-passant field was not `-` or a parseable algebraic square.
    case malformedEnPassant(String)
    /// The halfmove clock or fullmove number was not a valid integer in
    /// the required range (halfmove ≥ 0, fullmove ≥ 1).
    case malformedInteger(String)
}
