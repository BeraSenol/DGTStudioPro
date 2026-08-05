import Testing
@testable import DGTStudioPro

@Suite("GameState Replay")
struct GameStateReplayTests {
    
    // MARK: Empty / Trivial
    
    @Test func emptyMovesReturnsSameState() throws {
        let result = try GameState.starting.replay([])
        #expect(result == .starting)
    }
    
    @Test func singleMoveAdvancesState() throws {
        let result = try GameState.starting.replay(["e4"])
        #expect(result.position[Squares.e4] == .whitePawn)
        #expect(result.position[Squares.e2] == .empty)
        #expect(result.activeColor == .black)
    }
    
    // MARK: Real Games
    
    @Test func scholarsMateProducesCheckmate() throws {
        let moves = ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"]
        let final = try GameState.starting.replay(moves)
        
        #expect(final.isCheckmate)
        #expect(final.activeColor == .black)
        #expect(final.position[Squares.f7] == .whiteQueen)
    }
    
    @Test func italianOpeningRunsCleanly() throws {
        // 1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. O-O Nf6 5. d3 d6
        let moves = ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "O-O", "Nf6", "d3", "d6"]
        let final = try GameState.starting.replay(moves)
        
        #expect(final.position[Squares.g1] == .whiteKing)   // castled
        #expect(final.position[Squares.f1] == .whiteRook)   // castled
        #expect(!final.castlingRights.whiteKingSide)        // both rights revoked
        #expect(!final.castlingRights.whiteQueenSide)
        #expect(final.castlingRights.blackKingSide)         // black hasn't castled
    }
    
    @Test func enPassantSequence() throws {
        // 1. e4 a6 2. e5 d5 3. exd6 — white captures EP on move 3.
        let moves = ["e4", "a6", "e5", "d5", "exd6"]
        let final = try GameState.starting.replay(moves)
        
        #expect(final.position[Squares.d6] == .whitePawn)
        #expect(final.position[Squares.d5] == .empty)  // captured EP
        #expect(final.position[Squares.e5] == .empty)  // moved away
        #expect(final.enPassantTarget == nil)          // EP target consumed
    }
    
    // MARK: Error Reporting
    
    @Test func unparseableMoveAtIndexZero() {
        let expected = ReplayError.invalidMove(
            index: 0,
            san: "ZZZ",
            underlying: .malformed("ZZZ")
        )
        #expect(throws: expected) {
            _ = try GameState.starting.replay(["ZZZ"])
        }
    }
    
    @Test func unparseableMoveCarriesCorrectIndex() {
        let expected = ReplayError.invalidMove(
            index: 2,
            san: "ZZZ",
            underlying: .malformed("ZZZ")
        )
        #expect(throws: expected) {
            _ = try GameState.starting.replay(["e4", "e5", "ZZZ"])
        }
    }
    
    @Test func illegalMoveCarriesNoMatchUnderlying() {
        // `e5` from the starting position — pawn on e2 cannot reach e5 in one move.
        let expected = ReplayError.invalidMove(
            index: 0,
            san: "e5",
            underlying: .noMatchingMove("e5")
        )
        #expect(throws: expected) {
            _ = try GameState.starting.replay(["e5"])
        }
    }
    
    @Test func ambiguousMoveCarriesAmbiguousUnderlying() throws {
        // Set up a position where Nc3 is ambiguous (two knights on b1 and d1
        // both attacking c3). Use FEN-equivalent state directly.
        var pos = Position.empty
        pos[Squares.e1] = .whiteKing
        pos[Squares.e8] = .blackKing
        pos[Squares.b1] = .whiteKnight
        pos[Squares.d1] = .whiteKnight
        let state = GameState(
            position: pos,
            activeColor: .white,
            castlingRights: .none,
            enPassantTarget: nil,
            halfmoveClock: 0,
            fullmoveNumber: 1
        )
        
        let expected = ReplayError.invalidMove(
            index: 0,
            san: "Nc3",
            underlying: .ambiguous("Nc3", count: 2)
        )
        #expect(throws: expected) {
            _ = try state.replay(["Nc3"])
        }
    }
    
    // MARK: FEN Forwarding
    
    @Test func fenForwardingProducesGameState() throws {
        let final = try FEN.starting.replay(["e4", "e5"])
        #expect(final.position[Squares.e4] == .whitePawn)
        #expect(final.position[Squares.e5] == .blackPawn)
    }
    
    @Test func fenForwardingPropagatesErrors() {
        #expect(throws: ReplayError.self) {
            _ = try FEN.starting.replay(["ZZZ"])
        }
    }
}
