import Testing
@testable import DGTStudioPro

/// Pins the parts of `Piece` that only *views* consume, so they finally have
/// a unit witness.
///
/// Born from the M9 coverage audit (July 2026): the packed-rawValue plumbing
/// and `fenCharacter` were green through FEN and the move generators, but the
/// `imageNames` table and `imageName` accessor were exercised nowhere outside
/// `SquareView` — a typo in that table renders as an *invisible piece on the
/// mirror*, with no test able to notice. (`materialValue` had zero call sites
/// anywhere and was deleted by the same audit rather than tested.)
///
/// Nonisolated: `Piece` is a pure `Sendable` value type.
@Suite("Piece — Image Names and Packing")
struct PieceTests {
    
    // MARK: Image Names
    
    /// The exact asset-catalog spellings, pinned literally. If a name here
    /// ever disagrees with the catalog, the mirror shows an empty square —
    /// this test is the only witness that can fail loudly instead.
    @Test func imageNamesAreExactlySpelled() {
        let expected: [(Piece, String)] = [
            (.whitePawn,   "WhitePawn"),
            (.whiteKnight, "WhiteKnight"),
            (.whiteBishop, "WhiteBishop"),
            (.whiteRook,   "WhiteRook"),
            (.whiteQueen,  "WhiteQueen"),
            (.whiteKing,   "WhiteKing"),
            (.blackPawn,   "BlackPawn"),
            (.blackKnight, "BlackKnight"),
            (.blackBishop, "BlackBishop"),
            (.blackRook,   "BlackRook"),
            (.blackQueen,  "BlackQueen"),
            (.blackKing,   "BlackKing"),
        ]
        for (piece, name) in expected {
            #expect(piece.imageName == name, "\(name) mis-spelled in the table")
        }
        #expect(Piece.empty.imageName == nil)
    }
    
    /// Guards table holes if `PieceType` ever grows: every occupied
    /// combination must resolve to *some* name.
    @Test func everyColorTypeCombinationHasAnImageName() {
        for color in PieceColor.allCases {
            for type in PieceType.allCases {
                #expect(Piece(color, type).imageName != nil)
            }
        }
    }
    
    // MARK: Packed Raw Value
    
    /// The 4-bit packing (`color << 3 | type`) round-trips, all twelve
    /// occupied values are distinct, and `.empty` decodes to nil/nil — the
    /// layout the image table indexes by.
    @Test func packedRawValueRoundTripsColorAndType() {
        var raws: Set<UInt8> = []
        for color in PieceColor.allCases {
            for type in PieceType.allCases {
                let piece = Piece(color, type)
                #expect(piece.color == color)
                #expect(piece.type == type)
                raws.insert(piece.rawValue)
            }
        }
        #expect(raws.count == 12)
        #expect(Piece.empty.color == nil)
        #expect(Piece.empty.type == nil)
        #expect(Piece.empty.isOccupied == false)
    }
    
    // MARK: FEN Characters
    
    /// Uppercase for white, the +0x20 trick lowercases for black, and empty
    /// renders as the debug dot.
    @Test func fenCharactersCoverBothCasesAndEmpty() {
        let white = PieceType.allCases.map { Piece(.white, $0).fenCharacter }
        let black = PieceType.allCases.map { Piece(.black, $0).fenCharacter }
        #expect(String(white) == "PNBRQK")
        #expect(String(black) == "pnbrqk")
        #expect(Piece.empty.fenCharacter == ".")
    }

    /// The SAN letter table. The exhaustive switch is compiler-witnessed for
    /// *coverage*; the values themselves were pinned only incidentally,
    /// through whichever pieces the SAN serializer fixtures happened to move.
    /// The pawn's empty string is the load-bearing case — every pawn move's
    /// SAN starts with the target or the file letter precisely because this
    /// returns "".
    @Test func notationIsTheSANLetterAndPawnIsEmpty() {
        let letters = PieceType.allCases.map(\.notation)
        #expect(letters == ["", "N", "B", "R", "Q", "K"])
    }
}
