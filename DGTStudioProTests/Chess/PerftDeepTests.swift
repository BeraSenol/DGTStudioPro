import Testing
@testable import DGTStudioPro

/// Deep perft — depth 5, all six canonical positions, ~468M leaf nodes (~10–33 min; excluded
/// from the default plan via the `.slow` tag). **Never delete**: depth 5 is what makes the
/// counts a proof rather than a spot check.
@Suite("Perft Deep (Depth 5)", .tags(.slow))
struct PerftDeepTests {

    // MARK: Perft Implementation
    private func perft(_ state: GameState, depth: Int) -> Int {
        if depth == 0 { return 1 }
        let moves = state.legalMoves()
        if depth == 1 { return moves.count }
        var total = 0
        for move in moves {
            total += perft(state.applying(move), depth: depth - 1)
        }
        return total
    }

    // MARK: Reference Position FENs
    private static let kiwipete =
    "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"
    private static let position3 =
    "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -"
    private static let position4 =
    "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq -"
    private static let position5 =
    "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -"
    private static let position6 =
    "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - -"

    // MARK: Depth-5 Reference Counts

    /// ~4.9M nodes. Fastest of the six — a useful warm-up that catches
    /// regressions in the basic move generation before committing to the
    /// slower tests.
    @Test func startingPositionDepth5() {
        #expect(perft(.starting, depth: 5) == 4_865_609)
    }

    /// ~193.7M nodes — Kiwipete at depth 5 exercises virtually every generator interaction at scale.
    @Test func kiwipeteDepth5() throws {
        let state = GameState(try FEN(parsing: Self.kiwipete))
        #expect(perft(state, depth: 5) == 193_690_690)
    }

    /// ~675K nodes — sparse endgame, the fastest of the non-starting
    /// positions. Stresses en passant and discovered attacks at scale
    /// (52K captures, 1165 en-passants at this depth).
    @Test func position3Depth5() throws {
        let state = GameState(try FEN(parsing: Self.position3))
        #expect(perft(state, depth: 5) == 674_624)
    }

    /// ~15.8M nodes. Promotion-heavy. Depth 5 here is the depth that
    /// exercises both the white a7→a8 promotion path and black's
    /// b2→b1/g2→g1 promotion paths, with captures and castling interplay.
    @Test func position4Depth5() throws {
        let state = GameState(try FEN(parsing: Self.position4))
        #expect(perft(state, depth: 5) == 15_833_292)
    }

    /// ~89.9M nodes. Promotion-with-capture stress. The white pawn on d7
    /// promotes by single push or by capture onto c8/e8, and the black
    /// knight on f2 generates a fan of discovered-attack lines that test
    /// pin detection across the king's diagonal.
    @Test func position5Depth5() throws {
        let state = GameState(try FEN(parsing: Self.position5))
        #expect(perft(state, depth: 5) == 89_941_194)
    }

    /// ~164.1M nodes. Dense middlegame with high branching factor. No
    /// special-case features (no castling, no EP, no near-promotion) —
    /// just enormous breadth, which tends to catch generator bugs that
    /// only manifest under unusual piece interactions in the leaves.
    @Test func position6Depth5() throws {
        let state = GameState(try FEN(parsing: Self.position6))
        #expect(perft(state, depth: 5) == 164_075_551)
    }
}
