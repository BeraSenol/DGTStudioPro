import Testing
@testable import DGTStudioPro

/// The lifted-piece destination hints (16 Aug 2026). Nonisolated - a pure fold over
/// `GameState` + `Position`, and the suite is the witness it stays reachable off the main actor.
/// The rule under test throughout: hints exist only when the physical board is exactly the
/// committed position minus one piece; every ambiguity yields the empty set.
@Suite("Move Hints - Lifted Piece Destinations")
struct MoveHintsTests {

    /// The committed position with one square emptied - the canonical single lift.
    private func lifted(_ square: Square, from state: GameState) -> Position {
        var physical = state.position
        physical[square] = .empty
        return physical
    }

    @Test func aLiftedKnightHintsItsTwoOpeningSquares() {
        let physical = lifted(Squares.b1, from: .starting)
        #expect(
            MoveHints.destinations(for: .starting, physical: physical)
                == [Squares.a3, Squares.c3]
        )
    }

    @Test func aLiftedPawnHintsSingleAndDoubleStep() {
        let physical = lifted(Squares.e2, from: .starting)
        #expect(
            MoveHints.destinations(for: .starting, physical: physical)
                == [Squares.e3, Squares.e4]
        )
    }

    /// A capture destination is a hint too - the occupied square the ring renders on.
    @Test func captureSquaresAreIncluded() throws {
        let state = try GameState(
            FEN(parsing: "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2")
        )
        let physical = lifted(Squares.e4, from: state)
        #expect(
            MoveHints.destinations(for: state, physical: physical)
                == [Squares.e5, Squares.d5]
        )
    }

    /// A pinned piece hints nothing - the fold is `legalMoves()`, never pseudo-legal reach.
    @Test func aPinnedPieceHintsNothing() throws {
        // Knight d2 pinned along the d-file: rook d8, king d1.
        let state = try GameState(
            FEN(parsing: "3r3k/8/8/8/8/8/3N4/3K4 w - - 0 1")
        )
        let physical = lifted(Squares.d2, from: state)
        #expect(MoveHints.destinations(for: state, physical: physical).isEmpty)
    }

    @Test func anUndisturbedBoardHintsNothing() {
        #expect(
            MoveHints.destinations(for: .starting, physical: Position.starting).isEmpty
        )
    }

    /// The pre-connect state: every square differs, and the answer is silence, not 32 guesses.
    @Test func theEmptyBoardHintsNothing() {
        #expect(
            MoveHints.destinations(for: .starting, physical: .empty).isEmpty
        )
    }

    @Test func twoLiftsHintNothing() {
        var physical = Position.starting
        physical[Squares.b1] = .empty
        physical[Squares.g1] = .empty
        #expect(MoveHints.destinations(for: .starting, physical: physical).isEmpty)
    }

    /// Lift plus a placement is a move in flight, `DGTReconstructor`'s business - not a hint state.
    @Test func aPlacedPieceCancelsTheHints() {
        var physical = Position.starting
        physical[Squares.b1] = .empty
        physical[Squares.c3] = .whiteKnight
        #expect(MoveHints.destinations(for: .starting, physical: physical).isEmpty)
    }

    /// The opponent's piece on your turn: one clean lift, zero legal moves - empty for free.
    @Test func anOpponentsLiftedPieceHintsNothing() {
        let physical = lifted(Squares.b8, from: .starting)
        #expect(MoveHints.destinations(for: .starting, physical: physical).isEmpty)
    }

    @Test func aNilGameHintsNothing() {
        #expect(
            MoveHints.destinations(for: nil, physical: .starting).isEmpty
        )
    }
}
