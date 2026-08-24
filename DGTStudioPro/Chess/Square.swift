/// A board index, `rank * 8 + file`: a1 = 0 through h8 = 63.
///
/// **It is a bare `Int`, so the extension below lands on every `Int` in the app.** `5.file` and
/// `someCount.algebraicNotation` both compile, and the second traps - unlike `asciiDigit` it carries
/// no bounds assert, because a real square is always 0-63. That is the cost of the typealias, paid
/// so board geometry has exactly one home.
typealias Square = Int

/// Named indices, rank-major: a1 = 0, h1 = 7, a8 = 56, h8 = 63.
enum Squares {
    static let a1 = 0,  b1 = 1,  c1 = 2,  d1 = 3,  e1 = 4,  f1 = 5,  g1 = 6,  h1 = 7
    static let a2 = 8,  b2 = 9,  c2 = 10, d2 = 11, e2 = 12, f2 = 13, g2 = 14, h2 = 15
    static let a3 = 16, b3 = 17, c3 = 18, d3 = 19, e3 = 20, f3 = 21, g3 = 22, h3 = 23
    static let a4 = 24, b4 = 25, c4 = 26, d4 = 27, e4 = 28, f4 = 29, g4 = 30, h4 = 31
    static let a5 = 32, b5 = 33, c5 = 34, d5 = 35, e5 = 36, f5 = 37, g5 = 38, h5 = 39
    static let a6 = 40, b6 = 41, c6 = 42, d6 = 43, e6 = 44, f6 = 45, g6 = 46, h6 = 47
    static let a7 = 48, b7 = 49, c7 = 50, d7 = 51, e7 = 52, f7 = 53, g7 = 54, h7 = 55
    static let a8 = 56, b8 = 57, c8 = 58, d8 = 59, e8 = 60, f8 = 61, g8 = 62, h8 = 63
}

extension Square {
    
    // MARK: Static Constants
    static let count = 64
    static let files = 0..<8
    static let ranks = 0..<8
    static let all = (0..<Square.count)
    
    /// Board-geometry offsets, shared by movegen, attack scanning and mate classification. Every
    /// use pairs one with a file-distance guard - an offset alone wraps the a/h seam.
    /// `queenDirections` is spelled out despite equalling `kingOffsets`: the coincidence is arithmetic.
    static let knightOffsets:    [Int] = [17, 15, 10, 6, -6, -10, -15, -17]
    static let kingOffsets:      [Int] = [1, 7, 8, 9, -1, -7, -8, -9]
    static let rookDirections:   [Int] = [1, 8, -1, -8]
    static let bishopDirections: [Int] = [7, 9, -7, -9]
    static let queenDirections:  [Int] = [1, 7, 8, 9, -1, -7, -8, -9]
    
    /// The two squares a pawn of `color` attacks *from*, as offsets from the **attacked** square -
    /// backwards, which is the direction `isSquareAttacked` scans and the opposite of the direction
    /// a pawn moves. The one colour-dependent member of this block, shared by
    /// `Position.isSquareAttacked` and `SpecialCheckmate.Context.pawnAttacks` so the convention is
    /// stored once rather than described twice. Pairs with a file-distance guard of 1, like the rest.
    static func pawnAttackOrigins(of color: PieceColor) -> [Int] {
        color == .white ? [-7, -9] : [7, 9]
    }
    
    static func fileCharacter(_ file: Int) -> Character {
        fileIndicatorTable[file]
    }
    
    static func rankCharacter(_ rank: Int) -> Character {
        rankIndicatorTable[rank]
    }
    
    /// Inverses of `fileCharacter` / `rankCharacter`; nil outside 0-7.
    static func file(from character: Character) -> Int? {
        index(of: character, base: "a", in: Square.files)
    }
    
    static func rank(from character: Character) -> Int? {
        index(of: character, base: "1", in: Square.ranks)
    }
    
    /// `bounds` is a parameter rather than a constant: this serves both `file(from:)` and
    /// `rank(from:)`, and hardcoding `Square.files` made the rank path bounds-check the file range.
    /// Identical values today - which is the state a shared constant drifts out of.
    private static func index(
        of character: Character, base: Unicode.Scalar, in bounds: Range<Int>
    ) -> Int? {
        guard let value = character.asciiValue else { return nil }
        let index = Int(value) - Int(UInt8(ascii: base))
        return bounds.contains(index) ? index : nil
    }
    
    private static let algebraicNotationTable: [String] = {
        Square.all.map { square in
            let file = Character(UnicodeScalar(Int(UnicodeScalar("a").value) + square % 8)!)
            let rank = Character(UnicodeScalar(Int(UnicodeScalar("1").value) + square / 8)!)
            return String(file) + String(rank)
        }
    }()
    
    private static let fileIndicatorTable: [Character] = {
        Square.files.map {
            Character(UnicodeScalar(Int(UnicodeScalar("a").value) + $0)!)
        }
    }()
    
    private static let rankIndicatorTable: [Character] = {
        Square.ranks.map {
            Character(UnicodeScalar(Int(UnicodeScalar("1").value) + $0)!)
        }
    }()
    
    // MARK: Computed Properties
    
    /// One comparison covers both ends: the bit-pattern cast turns a negative square into a huge
    /// `UInt`, so off-board-below and off-board-above fail the same test.
    var isOnBoard: Bool { UInt(bitPattern: self) < Square.count }
    var file: Int { self % 8 }
    var rank: Int { self / 8 }
    
    var fileIndicator: Character {
        Int.fileIndicatorTable[file]
    }
    
    var rankIndicator: Character {
        Int.rankIndicatorTable[rank]
    }
    
    /// A FEN empty-run digit, so 0-8 rather than a square index. `assert`, not `precondition`:
    /// Release trusts the caller.
    var asciiDigit: Character {
        assert(UInt(bitPattern: self) <= 8, "asciiDigit called with value \(self), expected 0–8")
        return Character(UnicodeScalar(UInt8(ascii: "0") + UInt8(self)))
    }
    
    var algebraicNotation: String {
        Int.algebraicNotationTable[self]
    }
    
    // MARK: Static Methods
    static func fromAlgebraicNotation(_ name: String) -> Square? {
        var utf8 = name.utf8.makeIterator()
        
        guard let fileByte = utf8.next(),
              let rankByte = utf8.next(),
              utf8.next() == nil else {
            return nil
        }
        
        let file = Int(fileByte) - Int(UInt8(ascii: "a"))
        let rank = Int(rankByte) - Int(UInt8(ascii: "1"))
        
        guard UInt(bitPattern: file) < 8,
              UInt(bitPattern: rank) < 8 else {
            return nil
        }
        
        return rank * 8 + file
    }
}
