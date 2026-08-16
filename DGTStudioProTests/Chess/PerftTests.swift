import Testing
@testable import DGTStudioPro

/// Perft against canonical reference counts - a mismatch points at a specific bug class
/// (Kiwipete: castling and pins; Position 3: EP; Position 5: promotions).
@Suite("Perft Move Generation Integrity")
struct PerftTests {
    
    // MARK: Depth-1 Smoke Test
    
    /// Depth-1 across all six - milliseconds, and catches direct generation bugs.
    @Test func allPositionsAtDepth1() throws {
        let cases: [(name: String, fen: String, expected: Int)] = [
            ("Starting",   FEN.startingString, 20),
            ("Kiwipete",   Chess.kiwipete,     48),
            ("Position 3", Chess.position3,    14),
            ("Position 4", Chess.position4,     6),
            ("Position 4M", Chess.position4Mirror, 6),
            ("Position 5", Chess.position5,    44),
            ("Position 6", Chess.position6,    46),
        ]
        
        for testCase in cases {
            let state = try GameState.parsing(testCase.fen)
            let count = Chess.perft(state, depth: 1)
            #expect(
                count == testCase.expected,
                "\(testCase.name) depth-1: expected \(testCase.expected), got \(count)"
            )
        }
    }
    
    // MARK: Depth-4 Reference Counts
    
    /// Starting position - the most-cited reference value. Touches every
    /// piece type but exercises no edge cases directly (no captures, no
    /// castling, no EP, no promotion in the first four plies).
    @Test func startingPositionDepth4() {
        #expect(Chess.perft(.starting, depth: 4) == 197_281)
    }
    
    /// Kiwipete (the canonical "exercises everything" middlegame). Both
    /// sides retain castling rights, bishop pin diagonals are live, and
    /// the queen/knight have capture options - historically the position
    /// that catches the most common move-generator bugs.
    @Test func kiwipeteDepth4() throws {
        let state = try GameState.parsing(Chess.kiwipete)
        #expect(Chess.perft(state, depth: 4) == 4_085_603)
    }
    
    /// Position 3 - sparse endgame on a near-empty board, chosen to
    /// exercise en passant capture and discovered attacks (the b-file
    /// rook battery and the kings on a5/h4 are geometrically arranged to
    /// produce many pinned-piece situations).
    @Test func position3Depth4() throws {
        let state = try GameState.parsing(Chess.position3)
        #expect(Chess.perft(state, depth: 4) == 43_238)
    }
    
    /// Position 4 - promotion-heavy. White has a passed a7 pawn and black
    /// has passed pawns on b2 and g2 all racing to promote. Castling
    /// rights remain only for black. Exercises all four promotion targets
    /// across both colors interleaved with captures.
    @Test func position4Depth4() throws {
        let state = try GameState.parsing(Chess.position4)
        #expect(Chess.perft(state, depth: 4) == 422_333)
    }
    
    /// Position 4's mirror, same count by construction - a mismatch between the pair localizes a
    /// colour asymmetry.
    @Test func position4MirrorDepth4() throws {
        let state = try GameState.parsing(Chess.position4Mirror)
        #expect(Chess.perft(state, depth: 4) == 422_333)
    }

    /// Position 5 - white pawn on d7 ready to promote with capture
    /// possibilities to c8 or e8, plus a black knight on f2 creating
    /// discovered-attack threats against the white king's home square.
    /// Stresses promotion-with-capture interactions.
    @Test func position5Depth4() throws {
        let state = try GameState.parsing(Chess.position5)
        #expect(Chess.perft(state, depth: 4) == 2_103_487)
    }
    
    /// Position 6 - dense middlegame, ~46 moves per node, the slowest depth-4 case.
    @Test func position6Depth4() throws {
        let state = try GameState.parsing(Chess.position6)
        #expect(Chess.perft(state, depth: 4) == 3_894_594)
    }
}
