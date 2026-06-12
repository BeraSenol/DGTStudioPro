//
//  DGTLiveSessionsTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Coverage for `DGTLiveSession` — the live-play coordinator. The architecture
/// invariant under test is that the published UI flags (`liveGame`,
/// `awaitingPhysicalSetup`, `needsRecovery`) are *derived* from a single
/// private `Mode`, so they can never contradict one another. These assertions
/// drive the synchronous lifecycle (`startNewGame` / `discardGame` / `resign` /
/// `agreeDraw`) and read the derived flags directly.
///
/// `@MainActor`: the session is an `@Observable @MainActor` class.
///
/// ## Timing note
///
/// `boardChanged(_:)` arms a 300 ms quiescence `Task`; `settle` runs only when
/// it fires. In the **synchronous** tests below, that task is scheduled but
/// never executes (the test holds the main actor straight through, so `settle`
/// can't interleave) — the assertions are therefore deterministic, observing
/// state set by the synchronous lifecycle calls alone. The handful of tests
/// that genuinely need `settle` are grouped under "Timer-Driven Settle" and
/// `await` past the quiescence window; those are timing-dependent by nature
/// (a heavily loaded machine could in principle need a longer margin).
@MainActor
@Suite("DGT Live Session")
struct DGTLiveSessionTests {

    private func roster() -> LiveGame.Roster {
        .init(white: "White", black: "Black")
    }

    // MARK: Idle

    @Test func freshSessionIsIdle() {
        let session = DGTLiveSession()

        #expect(session.liveGame == nil)
        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.needsRecovery == false)
        #expect(session.shouldOfferNewGame == false)
        #expect(session.castlingGhostSquare == nil)
        #expect(session.castlingGhostPiece == nil)
        #expect(session.correctionHint == nil)
    }

    // MARK: startNewGame

    /// With no physical board observed yet, a new game can't be confirmed as
    /// set up, so the session enters `awaitingSetup`: `liveGame` is present,
    /// `awaitingPhysicalSetup` is true, and recovery is false. The derived
    /// flags being mutually exclusive is the whole point of the single `Mode`.
    @Test func startNewGameWithoutMatchingBoardAwaitsSetup() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())

        #expect(session.liveGame != nil)
        #expect(session.awaitingPhysicalSetup == true)
        #expect(session.needsRecovery == false)
        #expect(session.shouldOfferNewGame == false)
        // The two suppression flags can never both be set.
        #expect(!(session.awaitingPhysicalSetup && session.needsRecovery))
    }

    /// When the last observed board already matches the new game's start (the
    /// common path — the dialog appears *because* the start was detected), the
    /// session goes straight to `playing`: a game is present and neither
    /// suppression flag is set. (`boardChanged` only records the board here;
    /// its quiescence task can't run before the synchronous assertions.)
    @Test func startNewGameWithBoardAlreadyAtStartBeginsPlaying() {
        let session = DGTLiveSession()
        session.boardChanged(.starting)          // records lastObservedBoard synchronously
        session.startNewGame(roster: roster())

        #expect(session.liveGame != nil)
        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.needsRecovery == false)
    }

    // MARK: discardGame

    @Test func discardGameReturnsToIdle() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())
        #expect(session.liveGame != nil)

        session.discardGame()

        #expect(session.liveGame == nil)
        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.needsRecovery == false)
        #expect(session.castlingGhostSquare == nil)
        #expect(session.correctionHint == nil)
    }

    // MARK: Manual Result Passthrough

    /// `resign` forwards to the running game (the other side wins). Reached via
    /// `awaitingSetup` — no `boardChanged`, so no quiescence task is armed and
    /// the test is fully deterministic.
    @Test func resignForwardsToLiveGame() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())

        session.resign(.white)

        #expect(session.liveGame?.result == .blackWins)
        #expect(session.liveGame?.isFinished == true)
    }

    @Test func agreeDrawForwardsToLiveGame() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())

        session.agreeDraw()

        #expect(session.liveGame?.result == .draw)
        #expect(session.liveGame?.isFinished == true)
    }

    // MARK: Roster Passthrough

    /// `updateRoster` forwards edited metadata to the running game — and is a
    /// safe no-op without one. Routing through the session (rather than views
    /// mutating the game) gives a single choke point for M4's draft saves.
    @Test func updateRosterForwardsToLiveGame() {
        let session = DGTLiveSession()

        // No game running: must not crash, must remain idle.
        session.updateRoster(.init(white: "Nobody", black: "Nobody"))
        #expect(session.liveGame == nil)

        session.startNewGame(roster: roster())

        var edited = roster()
        edited.event = "Club Night"
        edited.white = "Heylen, Christophe"
        session.updateRoster(edited)

        #expect(session.liveGame?.roster.event == "Club Night")
        #expect(session.liveGame?.roster.white == "Heylen, Christophe")
    }

    // MARK: Timer-Driven Settle (timing-dependent)

    /// After the quiescence window elapses on the start position while idle,
    /// the session offers a new game; dismissing clears the offer. Awaits a
    /// generous margin past the 300 ms window.
    @Test func settlingOnStartPositionOffersANewGame() async throws {
        let session = DGTLiveSession()
        session.boardChanged(.starting)

        try await Task.sleep(for: .milliseconds(450))   // > 300 ms quiescence

        #expect(session.shouldOfferNewGame == true)

        session.dismissNewGameOffer()
        #expect(session.shouldOfferNewGame == false)
    }

    /// End-to-end live path: with a game playing, feeding the board after 1.e4
    /// and letting it settle commits exactly that move and advances the game,
    /// without tripping recovery.
    @Test func settlingAfterAMoveCommitsIt() async throws {
        let session = DGTLiveSession()
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())       // already-set-up → playing

        let e4 = try GameState.starting.parseSAN("e4")
        let boardAfterE4 = GameState.starting.applying(e4).position
        session.boardChanged(boardAfterE4)            // cancels the prior task, arms a new one

        try await Task.sleep(for: .milliseconds(450))

        #expect(session.liveGame?.plyCount == 1)
        #expect(session.liveGame?.sanMoves == ["e4"])
        #expect(session.needsRecovery == false)
    }

    /// Once a game is decided, post-result board changes are expected (pieces
    /// cleared, reset) and must never trip recovery. Instead, settling on the
    /// standard start offers a fresh game — the finish → reset → play-again
    /// loop. The garbled intermediate position would have been `.unresolved`
    /// (→ recovery) while playing, so this genuinely distinguishes the
    /// finished-game branch.
    @Test func settlingAfterFinishOffersNewGameInsteadOfRecovery() async throws {
        let session = DGTLiveSession()
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())        // already-set-up → playing
        session.resign(.white)                        // decided: 0-1, still on screen

        // Players clearing pieces: an arbitrary garbled position mid-cleanup.
        var garbled = Position.starting
        garbled[Squares.e7] = .empty
        garbled[Squares.e4] = .blackPawn
        session.boardChanged(garbled)

        try await Task.sleep(for: .milliseconds(450))

        #expect(session.needsRecovery == false)
        #expect(session.liveGame?.isFinished == true)

        // Pieces back on their home squares → the new-game offer fires.
        session.boardChanged(.starting)

        try await Task.sleep(for: .milliseconds(450))

        #expect(session.needsRecovery == false)
        #expect(session.shouldOfferNewGame == true)
    }
}
