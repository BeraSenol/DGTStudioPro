internal struct FEN: Equatable, Sendable {
    
    // MARK: Static Constants
    internal static let starting = FEN(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    internal static let startingString = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    
    // MARK: Stored Properties
    internal let position: Position
    internal let activeColor: PieceColor
    internal let castlingRights: CastlingRights
    internal let enPassantTarget: Square?
    internal let halfmoveClock: Int
    internal let fullmoveNumber: Int
    
    // MARK: Computed Properties
    internal var string: String {
        "\(positionKey) \(halfmoveClock) \(fullmoveNumber)"
    }
    
    internal var positionKey: String {
        let color: Character = activeColor == .white ? "w" : "b"
        let enPassant = enPassantTarget?.algebraicNotation ?? "-"
        return "\(piecePlacement) \(color) \(castlingRights.fen) \(enPassant)"
    }
    
    internal var piecePlacement: String {
        var result = ""
        result.reserveCapacity(72)
        
        for rank in Square.ranks.reversed() {
            if rank < 7 { result.append("/") }
            var emptyRun = 0
            
            for file in Square.files {
                let piece = position[rank * 8 + file]
                
                if piece.isOccupied {
                    if emptyRun > 0 {
                        result.append(emptyRun.asciiDigit)
                        emptyRun = 0
                    }
                    result.append(piece.fenCharacter)
                } else {
                    emptyRun += 1
                }
            }
            
            if emptyRun > 0 {
                result.append(emptyRun.asciiDigit)
            }
        }
        
        return result
    }
}

// MARK: Move Generation

extension FEN {
    /// Legal moves from this position, via `GameState` — the single source of
    /// legality.
    ///
    /// **Test-only by decision, not rot.** No production caller: every app path
    /// already holds a `GameState`. It is kept because it is the one symbol
    /// that exercises the `FEN` → `GameState` conversion init against real
    /// generation, so a drift between the two six-field shapes fails a test
    /// rather than surfacing as a wrong move list somewhere downstream. See
    /// the waiver register's "test-only by decision" list.
    internal func legalMoves() -> [Move] {
        GameState(self).legalMoves()
    }
}

// MARK: - String Parsing
//
// Folded in from `FEN+Parsing.swift` at M13 (6 Aug 2026). The type was 80
// lines and its parsing extension 209, so the split read as a peer pair when
// the parsing half is the substance — and the boundary-hardening rules
// (`FENParseError`'s cases, the rejections move generation depends on) now sit
// beside the fields they harden rather than one file over.
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
    internal init(parsing string: String) throws(FENParseError) {
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
    private static func parsePlacement(_ field: String) throws(FENParseError) -> Position {
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
                // ASCII-only: `wholeNumberValue` is true for `٥`, `Ⅷ`, `五` and the
                // fullwidth forms, each of which would parse as an empty-square run.
                // The draft sidecar is user-editable (`LiveGame+Draft` resumes through
                // this parser), so this is the untrusted-file boundary the `[%eval …]`
                // lesson names, not a theoretical one.
                if char.isASCII, let digit = char.wholeNumberValue, (1...8).contains(digit) {
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
    private static func parseActiveColor(_ field: String) throws(FENParseError) -> PieceColor {
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
    private static func parseCastling(_ field: String) throws(FENParseError) -> CastlingRights {
        if field == "-" { return .none }
        
        var raw: UInt8 = 0
        
        // No `Set` needed: the character→bit map is injective, so a duplicate
        // character *is* an already-set bit. The rejection contract is
        // unchanged — `KQkqK` and `KK` still throw.
        for char in field {
            let mask: UInt8
            switch char {
            case "K": mask = CastlingRights.mask(for: .white, .kingSide).rawValue
            case "Q": mask = CastlingRights.mask(for: .white, .queenSide).rawValue
            case "k": mask = CastlingRights.mask(for: .black, .kingSide).rawValue
            case "q": mask = CastlingRights.mask(for: .black, .queenSide).rawValue
            default:  throw FENParseError.malformedCastling(field)
            }
            guard raw & mask == 0 else { throw FENParseError.malformedCastling(field) }
            raw |= mask
        }
        
        return CastlingRights(rawValue: raw)
    }
    
    /// Parses the en-passant target field. Accepts `-` (no EP target) or a
    /// square in algebraic notation. Does not validate that the square is on
    /// a plausible EP rank — that's a position-validity concern, not a parse
    /// concern.
    private static func parseEnPassant(_ field: String) throws(FENParseError) -> Square? {
        if field == "-" { return nil }
        guard let square = Square.fromAlgebraicNotation(field) else {
            throw FENParseError.malformedEnPassant(field)
        }
        return square
    }
    
    /// Parses the halfmove clock. Must be a non-negative integer.
    private static func parseHalfmoveClock(_ field: String) throws(FENParseError) -> Int {
        // Digits only: `Int(_:)` accepts a leading sign, so `+5` and `-0` would both
        // pass the range test below while being malformed FEN.
        guard field.allSatisfy(\.isASCII), field.allSatisfy(\.isNumber),
              let value = Int(field), value >= 0 else {
            throw FENParseError.malformedInteger(field)
        }
        return value
    }
    
    /// Parses the fullmove number. Must be a positive integer (FEN spec
    /// requires fullmove ≥ 1; the starting position has fullmove 1).
    private static func parseFullmoveNumber(_ field: String) throws(FENParseError) -> Int {
        // Digits only — see `parseHalfmoveClock`. `+1` is not a fullmove number.
        guard field.allSatisfy(\.isASCII), field.allSatisfy(\.isNumber),
              let value = Int(field), value >= 1 else {
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

// MARK: Errors

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
