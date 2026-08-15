struct FEN: Equatable, Sendable {
    
    // MARK: Static Constants
    static let starting = FEN(
        position: .starting,
        activeColor: .white,
        castlingRights: .all,
        enPassantTarget: nil,
        halfmoveClock: 0,
        fullmoveNumber: 1
    )
    
    static let startingString = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    
    // MARK: Stored Properties
    let position: Position
    let activeColor: PieceColor
    let castlingRights: CastlingRights
    let enPassantTarget: Square?
    let halfmoveClock: Int
    let fullmoveNumber: Int
    
    // MARK: Computed Properties
    var string: String {
        "\(positionKey) \(halfmoveClock) \(fullmoveNumber)"
    }
    
    var positionKey: String {
        let color: Character = activeColor == .white ? "w" : "b"
        let enPassant = enPassantTarget?.algebraicNotation ?? "-"
        return "\(piecePlacement) \(color) \(castlingRights.fen) \(enPassant)"
    }
    
    var piecePlacement: String {
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
    /// Legal moves via `GameState` — the single source of legality. **Test-only by decision** (see
    /// the waiver register).
    func legalMoves() -> [Move] {
        GameState(self).legalMoves()
    }
}

// MARK: - String Parsing (folded in from FEN+Parsing.swift at M13 — 80 lines of type, 209 of extension)
extension FEN {
    
    // MARK: String Parsing (7P prerequisite)
    
    /// Parses full six-field FEN and the four-field placement-only form.
    init(parsing string: String) throws(FENParseError) {
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
    
    /// Piece-placement → `Position`. Ranks slash-separated top-to-bottom; each must total exactly 8 files.
    private static func parsePlacement(_ field: String) throws(FENParseError) -> Position {
        let ranks = field.split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else {
            throw FENParseError.malformedPlacement(field)
        }
        
        var position = Position.empty
        
        // ranks[0] is rank 8 (top).
        for (index, rankString) in ranks.enumerated() {
            let rank = 7 - index
            var file = 0
            
            for char in rankString {
                // ASCII-only: `wholeNumberValue` is true for `٥`, `Ⅷ`, `五` — and the draft sidecar resumes
                // through this parser, so this is a real untrusted-file boundary.
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
    
    /// `-` or a non-repeating subset of `KQkq` in any order; duplicates rejected (strict-on-shape).
    private static func parseCastling(_ field: String) throws(FENParseError) -> CastlingRights {
        if field == "-" { return .none }
        
        var raw: UInt8 = 0
        
        // No `Set`: the char→bit map is injective, so a duplicate character IS an already-set bit.
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
    
    /// `-` or an algebraic square. EP-rank plausibility is a position concern, not a parse concern.
    private static func parseEnPassant(_ field: String) throws(FENParseError) -> Square? {
        if field == "-" { return nil }
        guard let square = Square.fromAlgebraicNotation(field) else {
            throw FENParseError.malformedEnPassant(field)
        }
        return square
    }
    
    /// Parses the halfmove clock. Must be a non-negative integer.
    private static func parseHalfmoveClock(_ field: String) throws(FENParseError) -> Int {
        // Digits only: `Int(_:)` accepts a leading sign, so `+5` / `-0` would pass the range test.
        guard field.allSatisfy(\.isASCII), field.allSatisfy(\.isNumber),
              let value = Int(field), value >= 0 else {
            throw FENParseError.malformedInteger(field)
        }
        return value
    }
    
    /// Parses the fullmove number. Must be a positive integer (FEN spec
    /// requires fullmove ≥ 1; the starting position has fullmove 1).
    private static func parseFullmoveNumber(_ field: String) throws(FENParseError) -> Int {
        // Digits only — see `parseHalfmoveClock`.
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

enum FENParseError: Error, Equatable {
    /// The FEN string did not contain 4 or 6 whitespace-separated fields.
    case wrongFieldCount(Int)
    /// Wrong rank count, bad file total, unknown piece character, or invalid digit.
    case malformedPlacement(String)
    /// The active-color field was not `w` or `b`.
    case malformedActiveColor(String)
    /// A character outside `-KQkq`, or a duplicate right.
    case malformedCastling(String)
    /// The en-passant field was not `-` or a parseable algebraic square.
    case malformedEnPassant(String)
    /// Halfmove < 0 or fullmove < 1, or not an integer.
    case malformedInteger(String)
}
