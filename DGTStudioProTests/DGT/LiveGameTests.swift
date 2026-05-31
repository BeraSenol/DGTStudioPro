//
//  LiveGameTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 26/05/2026.
//

import Testing
@testable import DGTStudioPro

/// Tests for the live-game recording model: that committing moves advances the
/// state walk and SAN transcript, that the result auto-detects on checkmate and
/// stalemate, that illegal moves are rejected, and that manual results
/// (resignation / draw) and the finished-game guard behave.
///
/// `LiveGame` is `@MainActor`, so the whole suite is isolated to the main actor
/// (matching `PositionTests`). That lets the helpers (`newGame`, `play`) and
/// every test touch `currentState` / `commit` without per-member annotations.
@MainActor
@Suite("LiveGame")
struct LiveGameTests {

    private func newGame() -> LiveGame {
        LiveGame(roster: .init(white: "White", black: "Black"))
    }

    /// Plays a SAN line into a game, asserting each move commits.
    private func play(_ game: LiveGame, _ sans: [String]) throws {
        for san in sans {
            let move = try game.currentState.parseSAN(san)
            #expect(game.commit(move), "expected to commit \(san)")
        }
    }

    /// Scholar's mate — the most-reused finished-game line in this suite.
    private static let scholarsMate = ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"]

    // MARK: Recording

    @Test func committingMovesAdvancesStateAndTranscript() throws {
        let game = newGame()
        try play(game, ["e4", "e5", "Nf3"])

        #expect(game.plyCount == 3)
        #expect(game.sanMoves == ["e4", "e5", "Nf3"])
        #expect(game.states.count == 4)        // start + 3
        #expect(game.result == .ongoing)
        #expect(!game.isFinished)
        #expect(game.lastMove?.to == Squares.f3)
    }

    /// A custom (non-standard) start is a supported path: the model records
    /// from whatever position it's handed, with an empty piece tracker (since
    /// identities can't be inferred from a bare position). This exercises the
    /// `init(start:)` branch the new-game dialog will use for board-setup play.
    @Test func customStartRecordsMovesAndTranscript() throws {
        // A simple K+Q vs K position, White to move.
        let start = try GameState.parsing("7k/8/8/8/8/8/8/3QK3 w - - 0 1")
        let game = LiveGame(start: start, roster: .init(white: "W", black: "B"))

        let qd5 = try game.currentState.parseSAN("Qd5")
        #expect(game.commit(qd5))

        #expect(game.plyCount == 1)
        #expect(game.sanMoves == ["Qd5"])
        #expect(game.states.first == start)     // start preserved as states[0]
        #expect(game.result == .ongoing)
    }

    // MARK: Result Detection

    @Test func checkmateAutoDetectsWinner() throws {
        let game = newGame()
        try play(game, Self.scholarsMate)

        #expect(game.result == .whiteWins)
        #expect(game.isFinished)
    }

    @Test func stalemateAutoDetectsDraw() throws {
        // Start one move before a stalemate; Qg6 stalemates the black king.
        let start = try GameState.parsing("7k/8/5K2/8/6Q1/8/8/8 w - - 0 1")
        let game = LiveGame(start: start, roster: .init())

        let qg6 = try game.currentState.parseSAN("Qg6")
        #expect(game.commit(qg6))

        #expect(game.result == .draw)
        #expect(game.isFinished)
    }

    // MARK: Rejections

    @Test func illegalMoveIsRejectedAndChangesNothing() throws {
        let game = newGame()
        // e2→e5 is not a legal first move.
        let illegal = Move.make(
            from: Squares.e2, to: Squares.e5,
            pieceType: .pawn, pieceColor: .white
        )
        #expect(!game.commit(illegal))
        #expect(game.plyCount == 0)
        #expect(game.result == .ongoing)
    }

    /// The same rejection guarantee mid-game: a few legal moves in, an illegal
    /// move must leave the transcript and state walk untouched (not just the
    /// ply count). Guards against a partial mutation before the legality check.
    @Test func illegalMoveMidGameLeavesTranscriptIntact() throws {
        let game = newGame()
        try play(game, ["e4", "e5", "Nf3"])
        let sansBefore = game.sanMoves
        let stateCountBefore = game.states.count

        // A knight on f3 cannot jump to a5.
        let illegal = Move.make(
            from: Squares.f3, to: Squares.a5,
            pieceType: .knight, pieceColor: .white
        )
        #expect(!game.commit(illegal))

        #expect(game.sanMoves == sansBefore)
        #expect(game.states.count == stateCountBefore)
        #expect(game.plyCount == 3)
    }

    @Test func commitIsIgnoredAfterGameFinishes() throws {
        let game = newGame()
        try play(game, Self.scholarsMate)
        #expect(game.isFinished)

        // Any further move (even one that would be legal pre-mate) is ignored.
        let after = game.plyCount
        let someMove = game.currentState.legalMoves().first
        if let someMove {
            #expect(!game.commit(someMove))
        }
        #expect(game.plyCount == after)
    }

    // MARK: Manual Results

    @Test func resignationSetsTheOtherSideAsWinner() {
        let game = newGame()
        game.resign(.white)
        #expect(game.result == .blackWins)
        #expect(game.isFinished)
    }

    /// Resignation must work mid-game (not just at move zero) without disturbing
    /// the moves already recorded — the transcript is what gets archived.
    @Test func resignationMidGamePreservesTranscript() throws {
        let game = newGame()
        try play(game, ["d4", "d5", "c4"])
        game.resign(.black)

        #expect(game.result == .whiteWins)
        #expect(game.isFinished)
        #expect(game.sanMoves == ["d4", "d5", "c4"])
        #expect(game.plyCount == 3)
    }

    @Test func agreedDrawSetsDraw() {
        let game = newGame()
        game.agreeDraw()
        #expect(game.result == .draw)
    }

    @Test func agreedDrawMidGamePreservesTranscript() throws {
        let game = newGame()
        try play(game, ["e4", "c5"])
        game.agreeDraw()

        #expect(game.result == .draw)
        #expect(game.sanMoves == ["e4", "c5"])
    }

    @Test func manualResultIgnoredOnFinishedGame() throws {
        let game = newGame()
        try play(game, Self.scholarsMate)
        #expect(game.result == .whiteWins)

        // A resignation after a decisive result must not overwrite it.
        game.resign(.white)
        #expect(game.result == .whiteWins)
    }

    // MARK: D7 Archive Contract

    /// Pins the shape D7 (LiveGame → PGN) will read: a finished game exposes the
    /// seven-tag roster, a SAN transcript parallel to its plies, and a decisive
    /// `result`. If any of these drift, the persistence step inherits a broken
    /// contract — so it's asserted here, before D7 exists.
    @Test func finishedGameExposesPGNReadyFields() throws {
        let roster = LiveGame.Roster(
            event: "Test Open",
            site: "Testville",
            round: 4,
            white: "Alice",
            black: "Bob"
        )
        let game = LiveGame(roster: roster)
        try play(game, Self.scholarsMate)

        // Roster maps onto PGN's seven tags.
        #expect(game.roster.event == "Test Open")
        #expect(game.roster.white == "Alice")
        #expect(game.roster.black == "Bob")
        #expect(game.roster.round == 4)

        // Transcript is parallel to the plies and decisive.
        #expect(game.sanMoves.count == game.plyCount)
        #expect(game.sanMoves == Self.scholarsMate)
        #expect(game.result == .whiteWins)
        #expect(game.result.rawValue == "1-0")   // PGN Result tag string
    }
}
