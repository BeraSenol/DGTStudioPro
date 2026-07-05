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

    // MARK: updateRoster

    /// Edit Details routes through the session (M3.3): the running game's
    /// roster is replaced wholesale, giving the diagnostic timeline a
    /// breadcrumb and M4's draft persistence a single choke point to hook.
    @Test func updateRosterReplacesTheRunningGamesRoster() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())

        let edited = LiveGame.Roster(
            event: "Club Night",
            site: "Home",
            round: 3,
            white: "Alice",
            black: "Bob"
        )
        session.updateRoster(edited)

        #expect(session.liveGame?.roster == edited)
    }

    /// With no game running there is nothing to edit — a documented no-op.
    @Test func updateRosterWhileIdleIsANoOp() {
        let session = DGTLiveSession()

        session.updateRoster(LiveGame.Roster(white: "Alice", black: "Bob"))

        #expect(session.liveGame == nil)
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

    // MARK: Draft Persistence (M4)

    /// A store rooted in a unique temp directory, so tests never touch the
    /// real Application Support sidecar and never see each other's files.
    private func temporaryStore() -> LiveGameDraftStore {
        LiveGameDraftStore(
            directory: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
        )
    }

    /// `startNewGame` writes a roster-only snapshot immediately — the file
    /// is claimed before the first ply, so even a crash during move one
    /// still resurrects the roster.
    @Test func startNewGameSavesADraft() throws {
        let session = DGTLiveSession()
        let store = temporaryStore()
        session.draftStore = store

        session.startNewGame(roster: roster())

        let draft = try store.load()
        #expect(draft?.white == "White")
        #expect(draft?.sanMoves.isEmpty == true)
        #expect(draft?.result == .ongoing)
    }

    /// The core Decision #2 path: a committed ply lands in the file. Same
    /// timing pattern as `settlingAfterAMoveCommitsIt`.
    @Test func committedPlySavesTheDraft() async throws {
        let session = DGTLiveSession()
        let store = temporaryStore()
        session.draftStore = store

        session.boardChanged(.starting)
        session.startNewGame(roster: roster())

        let e4 = try GameState.starting.parseSAN("e4")
        session.boardChanged(GameState.starting.applying(e4).position)
        try await Task.sleep(for: .milliseconds(450))

        #expect(try store.load()?.sanMoves == ["e4"])
    }

    @Test func resignSavesTheDraft() throws {
        let session = DGTLiveSession()
        let store = temporaryStore()
        session.draftStore = store
        session.startNewGame(roster: roster())

        session.resign(.white)

        #expect(try store.load()?.result == .blackWins)
    }

    @Test func agreeDrawSavesTheDraft() throws {
        let session = DGTLiveSession()
        let store = temporaryStore()
        session.draftStore = store
        session.startNewGame(roster: roster())

        session.agreeDraw()

        #expect(try store.load()?.result == .draw)
    }

    @Test func updateRosterSavesTheDraft() throws {
        let session = DGTLiveSession()
        let store = temporaryStore()
        session.draftStore = store
        session.startNewGame(roster: roster())

        session.updateRoster(LiveGame.Roster(white: "Alice", black: "Bob"))

        #expect(try store.load()?.white == "Alice")
    }

    /// Decision #3's delete path reaches the disk: a discarded game must not
    /// resurrect as a resume offer at the next launch.
    @Test func discardDeletesTheDraft() throws {
        let session = DGTLiveSession()
        let store = temporaryStore()
        session.draftStore = store
        session.startNewGame(roster: roster())
        #expect(try store.load() != nil)

        session.discardGame()

        #expect(try store.load() == nil)
        #expect(session.pendingDraft == nil)
    }

    /// The launch path: a draft written by a "previous run" surfaces as a
    /// resumable offer, decoded and describable.
    @Test func loadPendingDraftFindsAResumableDraft() throws {
        let store = temporaryStore()
        let game = LiveGame(roster: roster())
        game.commit(try game.currentState.parseSAN("e4"))
        try store.save(game.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()

        #expect(session.resumableDraft?.white == "White")
        #expect(session.resumableDraft?.sanMoves == ["e4"])
        #expect(session.pendingDraftIsCorrupt == false)
    }

    /// The common launch: no file, no offer, no fuss.
    @Test func loadPendingDraftWithNoFileIsANoOp() {
        let session = DGTLiveSession()
        session.draftStore = temporaryStore()

        session.loadPendingDraft()

        #expect(session.pendingDraft == nil)
    }

    /// A file that exists but won't decode surfaces as `.corrupt` — never
    /// deleted behind the player's back, never silently ignored.
    @Test func corruptFileLoadsAsCorrupt() throws {
        let store = temporaryStore()
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: store.fileURL)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()

        #expect(session.pendingDraft == .corrupt)
        #expect(session.resumableDraft == nil)
    }

    /// Resume rebuilds the game by replay and enters the setup gate (no
    /// board observed yet → the pieces still need restoring), clearing the
    /// offer.
    @Test func resumePendingDraftRebuildsTheGameAndClearsTheOffer() throws {
        let store = temporaryStore()
        let original = LiveGame(roster: roster())
        original.commit(try original.currentState.parseSAN("e4"))
        try store.save(original.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()
        session.resumePendingDraft()

        #expect(session.liveGame?.sanMoves == ["e4"])
        #expect(session.liveGame?.plyCount == 1)
        #expect(session.awaitingPhysicalSetup == true)
        #expect(session.pendingDraft == nil)
    }

    /// When the physical board already matches the game's current position
    /// (pieces untouched across the relaunch), resume goes straight to
    /// `playing` — the same already-set-up shortcut as `startNewGame`.
    @Test func resumeWithBoardAlreadyAtCurrentPositionBeginsPlaying() throws {
        let store = temporaryStore()
        let original = LiveGame(roster: roster())
        let e4 = try original.currentState.parseSAN("e4")
        let afterE4 = original.currentState.applying(e4).position
        original.commit(e4)
        try store.save(original.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()
        session.boardChanged(afterE4)        // records lastObservedBoard synchronously
        session.resumePendingDraft()

        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.liveGame?.plyCount == 1)
    }

    @Test func deletePendingDraftRemovesFileAndOffer() throws {
        let store = temporaryStore()
        let game = LiveGame(roster: roster())
        try store.save(game.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()
        #expect(session.pendingDraft != nil)

        session.deletePendingDraft()

        #expect(session.pendingDraft == nil)
        #expect(try store.load() == nil)
    }

    /// While a resume offer pends, the start position must NOT trigger the
    /// new-game offer (the two would collide, and starting fresh would
    /// silently overwrite the offered draft). Declining the resume hands
    /// over to the ordinary offer on the spot.
    @Test func pendingDraftSuppressesTheNewGameOffer() async throws {
        let store = temporaryStore()
        let game = LiveGame(roster: roster())
        try store.save(game.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()

        session.boardChanged(.starting)
        try await Task.sleep(for: .milliseconds(450))
        #expect(session.shouldOfferNewGame == false)

        session.deletePendingDraft()
        #expect(session.shouldOfferNewGame == true)
    }

    /// Starting fresh forfeits the pending offer and claims the file for the
    /// new game (the destructive confirmation in the sheet is the UI guard).
    @Test func startNewGameClearsThePendingOffer() throws {
        let store = temporaryStore()
        let old = LiveGame(roster: .init(white: "Old", black: "Game"))
        try store.save(old.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()
        #expect(session.resumableDraft?.white == "Old")

        session.startNewGame(roster: roster())

        #expect(session.pendingDraft == nil)
        #expect(try store.load()?.white == "White")
    }

    /// A finished-but-unarchived draft (archiving lands in M5) resumes with
    /// its manual result re-applied — the game comes back decided, not
    /// half-forgotten.
    @Test func resumeOfAFinishedDraftReappliesTheResult() throws {
        let store = temporaryStore()
        let original = LiveGame(roster: roster())
        original.resign(.white)
        try store.save(original.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()
        session.resumePendingDraft()

        #expect(session.liveGame?.result == .blackWins)
        #expect(session.liveGame?.isFinished == true)
    }
}
