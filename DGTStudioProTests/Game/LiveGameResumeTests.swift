import Foundation
import Testing
@testable import DGTStudioPro

/// Tests for the draft ↔ game conversion (M4): `draftSnapshot` captures the
/// game faithfully, `init(resuming:)` replays a draft into an
/// equivalent-by-construction game, manual results are re-applied, and every
/// reachable `ResumeError` fires on the draft that deserves it.
///
/// `moveRejected` is deliberately untested: `parseSAN` only ever returns
/// moves that are legal in the current state (mate/stalemate positions have
/// none, so trailing moves fail at the parse step as `invalidMove`), which
/// makes the `commit` refusal a defensive rung with no reachable trigger
/// today. If the parser ever loosens, this is the note to revisit.
///
/// `LiveGame` is `@MainActor`, so the suite is too (matching
/// `LiveGameTests`).
@MainActor
@Suite("LiveGame Draft Resume")
struct LiveGameResumeTests {

    private func newGame() -> LiveGame {
        LiveGame(roster: .init(
            event: "Club Night",
            site: "Home",
            round: 3,
            white: "Wendy",
            black: "Blake"
        ))
    }

    /// Plays a SAN line into a game, asserting each move commits.
    private func play(_ game: LiveGame, _ sans: [String]) throws {
        for san in sans {
            let move = try game.currentState.parseSAN(san)
            #expect(game.commit(move))
        }
    }

    /// A hand-built draft for the error-path tests, standing in for a file
    /// this build never wrote.
    private func draft(
        startFEN: String = FEN(GameState.starting).string,
        sanMoves: [String] = [],
        result: GameResult = .ongoing
    ) -> LiveGameDraft {
        LiveGameDraft(
            schemaVersion: LiveGameDraft.currentSchemaVersion,
            startFEN: startFEN,
            ruleSet: .fide,
            event: "?",
            site: "?",
            date: nil,
            round: nil,
            white: "Wendy",
            black: "Blake",
            board: nil,
            sanMoves: sanMoves,
            result: result,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
    }

    // MARK: Snapshot

    @Test func snapshotCapturesTheGame() throws {
        let game = newGame()
        try play(game, ["e4", "e5"])

        let snapshot = game.draftSnapshot

        #expect(snapshot.schemaVersion == LiveGameDraft.currentSchemaVersion)
        #expect(snapshot.startFEN == FEN(GameState.starting).string)
        #expect(snapshot.event == "Club Night")
        #expect(snapshot.round == 3)
        #expect(snapshot.white == "Wendy")
        #expect(snapshot.black == "Blake")
        #expect(snapshot.sanMoves == ["e4", "e5"])
        #expect(snapshot.result == .ongoing)
        #expect(snapshot.startedAt == game.startedAt)
    }

    /// D28′ — the board identity survives the snapshot → resume round trip,
    /// so a crash-resumed game archives with the board that actually played
    /// it (the reason the field lives on the roster at all).
    @Test func boardIdentitySurvivesSnapshotAndResume() throws {
        let game = LiveGame(roster: .init(
            event: "Club Night",
            site: "Home",
            white: "Wendy",
            black: "Blake",
            board: "DGT 3000448278"
        ))
        try play(game, ["e4"])

        let snapshot = game.draftSnapshot
        #expect(snapshot.board == "DGT 3000448278")

        let resumed = try LiveGame(resuming: snapshot)
        #expect(resumed.roster.board == "DGT 3000448278")
    }

    // MARK: Resume — Success Paths

    /// The core replay guarantee: a resumed game reproduces the original's
    /// transcript, position, ply count, result, and start time.
    @Test func resumeReplaysToAnEquivalentGame() throws {
        let original = newGame()
        try play(original, ["e4", "e5", "Nf3"])

        let resumed = try LiveGame(resuming: original.draftSnapshot)

        #expect(resumed.sanMoves == original.sanMoves)
        // `FEN(_:)` at the call site — `currentFEN` was deleted 3 Aug 2026.
        #expect(FEN(resumed.currentState).string == FEN(original.currentState).string)
        #expect(resumed.plyCount == original.plyCount)
        #expect(resumed.result == .ongoing)
        #expect(resumed.startedAt == original.startedAt)
        #expect(resumed.roster.white == "Wendy")
    }

    /// A resignation is a manual result — the replay ends `.ongoing`, so
    /// the stored result is re-applied and the game comes back decided.
    @Test func resumeReappliesAManualResult() throws {
        let original = newGame()
        try play(original, ["e4"])
        original.resign(.white)

        let resumed = try LiveGame(resuming: original.draftSnapshot)

        #expect(resumed.result == .blackWins)
        #expect(resumed.isFinished)
    }

    @Test func resumeReappliesAnAgreedDraw() throws {
        let original = newGame()
        try play(original, ["e4", "e5"])
        original.agreeDraw()

        let resumed = try LiveGame(resuming: original.draftSnapshot)

        #expect(resumed.result == .draw)
        #expect(resumed.isFinished)
    }

    /// An auto-detected mate replays to the same terminal result, and the
    /// matching stored result passes reconciliation.
    @Test func resumeOfMateMatchesStoredResult() throws {
        let original = newGame()
        try play(original, ["f3", "e5", "g4", "Qh4#"])
        #expect(original.result == .blackWins)

        let resumed = try LiveGame(resuming: original.draftSnapshot)

        #expect(resumed.result == .blackWins)
        #expect(resumed.isFinished)
    }

    // MARK: Resume — Error Paths

    @Test func invalidStartFENThrows() {
        #expect(throws: LiveGame.ResumeError.invalidStart(fen: "garbage")) {
            try LiveGame(resuming: draft(startFEN: "garbage"))
        }
    }

    @Test func invalidMoveThrows() {
        #expect(throws: LiveGame.ResumeError.invalidMove(index: 0, san: "Zz9")) {
            try LiveGame(resuming: draft(sanMoves: ["Zz9"]))
        }
    }

    /// Moves continuing past a checkmate fail at the *parse* step — a mated
    /// position has no legal moves for SAN to match — so the diagnostic is
    /// `invalidMove` at the offending index (see the type doc on why
    /// `moveRejected` stays out of reach).
    @Test func movesAfterMateThrowInvalidMove() {
        let bad = draft(
            sanMoves: ["f3", "e5", "g4", "Qh4#", "e4"],
            result: .blackWins
        )

        #expect(throws: LiveGame.ResumeError.invalidMove(index: 4, san: "e4")) {
            try LiveGame(resuming: bad)
        }
    }

    /// The replay derives mate for Black; a draft claiming White won is
    /// inconsistent and must not resume.
    @Test func resultMismatchThrows() {
        let bad = draft(
            sanMoves: ["f3", "e5", "g4", "Qh4#"],
            result: .whiteWins
        )

        let expected = LiveGame.ResumeError.resultMismatch(
            stored: .whiteWins,
            replayed: .blackWins
        )
        #expect(throws: expected) {
            try LiveGame(resuming: bad)
        }
    }

    /// A terminal replay with a stored `.ongoing` is equally inconsistent:
    /// the draft is written after every commit, so a final-move mate is
    /// always already in the stored result.
    @Test func ongoingStoredResultAfterMateThrowsMismatch() {
        let bad = draft(
            sanMoves: ["f3", "e5", "g4", "Qh4#"],
            result: .ongoing
        )

        let expected = LiveGame.ResumeError.resultMismatch(
            stored: .ongoing,
            replayed: .blackWins
        )
        #expect(throws: expected) {
            try LiveGame(resuming: bad)
        }
    }

    /// The draft's transcript is the serializer's canonical SAN. A
    /// non-canonical spelling (`0-0` for `O-O`) parses and commits fine, but
    /// the replayed transcript then can't reproduce the stored one — the
    /// file was edited or written by diverging rules, and must not resume.
    @Test func nonCanonicalSANThrowsTranscriptMismatch() {
        let bad = draft(
            sanMoves: ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "0-0"]
        )

        #expect(throws: LiveGame.ResumeError.transcriptMismatch) {
            try LiveGame(resuming: bad)
        }
    }
}
