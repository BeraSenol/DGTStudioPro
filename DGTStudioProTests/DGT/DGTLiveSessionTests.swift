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
/// `boardChanged(_:)` arms a quiescence `Task` (`session.quiescence`, 300 ms
/// in production); `settle` runs only when it fires. In the **synchronous**
/// tests below, that task is scheduled but never executes (the test holds the
/// main actor straight through, so `settle` can't interleave) — the
/// assertions are therefore deterministic, observing state set by the
/// synchronous lifecycle calls alone. The tests that genuinely need `settle`
/// are grouped under "Timer-Driven Settle": they shrink `quiescence` to
/// 10 ms and `await settled(_:)` — awaiting the armed quiescence task
/// itself — so every assertion observes a settle that has definitely
/// run. (F7's full history, kept so it isn't relived: fixed 450 ms
/// sleeps raced the scheduler under parallel-suite load; the 2 s poll
/// that replaced them flaked the same way, as did its 5 s successor —
/// and a poll that returns silently on timeout passes vacuously, which
/// this suite did for a while without anyone noticing. Awaiting the
/// task needs no ceiling at all, so there is nothing left to re-guess.)
@MainActor
@Suite("DGT Live Session")
struct DGTLiveSessionTests {
    
    private func roster() -> LiveGame.Roster {
        .init(white: "White", black: "Black")
    }
    
    /// Awaits the armed settle, so everything after it observes a settle
    /// that has *definitely* run — deterministic, with no clock and no
    /// ceiling to re-guess (F7 superseded twice: a 2 s poll flaked, so
    /// did its 5 s replacement, and the poll's silent-return-on-timeout
    /// made every wait in this suite vacuous — the reason `poll` is gone
    /// rather than repaired). The `#require` is the vacuity guard: a nil
    /// task means no `boardChanged` preceded this call, and awaiting it
    /// would pass for the wrong reason. The task inherits the session's
    /// main-actor context, so when this returns, `settle`'s mutations
    /// are fully visible to the caller.
    private func settled(_ session: DGTLiveSession) async throws {
        let armed = try #require(session.quiescenceTask)
        await armed.value
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

    /// D28′ — the one write to `Roster.board`: `startNewGame` stamps the
    /// hook's answer onto the roster, and a nil hook (headless tests, or a
    /// handshake that never reported a serial) leaves it nil — pre-M2
    /// archive shape, never an invented identity.
    @Test func startNewGameStampsBoardIdentityFromHook() {
        let session = DGTLiveSession()
        session.boardIdentity = { "DGT 3000448278" }
        session.startNewGame(roster: roster())

        #expect(session.liveGame?.roster.board == "DGT 3000448278")
    }

    @Test func startNewGameWithoutHookLeavesBoardNil() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())

        #expect(session.liveGame?.roster.board == nil)
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
    
    /// The July 2026 sanity-audit fix: a manual result during
    /// `awaitingSetup` normalizes to `playing` — the game is decided, so
    /// there is nothing left to set up. Before the fix the session stayed
    /// in `awaitingSetup` with a finished game: `hudPhase` (which ranks
    /// `awaitingPhysicalSetup` above `isFinished`) kept prompting for
    /// setup and never reached the finished banner or its New Game
    /// button. Fully deterministic — no `boardChanged`, so no quiescence
    /// task is armed.
    @Test func resignDuringSetupEndsTheSetupWait() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())      // no board seen → awaitingSetup
        #expect(session.awaitingPhysicalSetup == true)
        
        session.resign(.black)
        
        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.needsRecovery == false)
        #expect(session.liveGame?.isFinished == true)
        #expect(session.liveGame?.result == .whiteWins)
    }
    
    /// The draw twin — the same normalization covers both manual results.
    @Test func agreeDrawDuringSetupEndsTheSetupWaitToo() {
        let session = DGTLiveSession()
        session.startNewGame(roster: roster())
        #expect(session.awaitingPhysicalSetup == true)
        
        session.agreeDraw()
        
        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.liveGame?.result == .draw)
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
    
    // MARK: Timer-Driven Settle (quiescence-driven, polled)
    
    /// After the quiescence window elapses on the start position while idle,
    /// the session offers a new game; dismissing clears the offer.
    @Test func settlingOnStartPositionOffersANewGame() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        session.boardChanged(.starting)

        try await settled(session)
        #expect(session.shouldOfferNewGame == true)

        session.dismissNewGameOffer()
        #expect(session.shouldOfferNewGame == false)
    }
    
    /// End-to-end live path: with a game playing, feeding the board after 1.e4
    /// and letting it settle commits exactly that move and advances the game,
    /// without tripping recovery.
    @Test func settlingAfterAMoveCommitsIt() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())       // already-set-up → playing
        
        let e4 = try GameState.starting.parseSAN("e4")
        let boardAfterE4 = GameState.starting.applying(e4).position
        session.boardChanged(boardAfterE4)            // cancels the prior task, arms a new one

        try await settled(session)

        #expect(session.liveGame?.plyCount == 1)
        #expect(session.liveGame?.sanMoves == ["e4"])
        #expect(session.needsRecovery == false)
    }
    
    /// An unexplainable board settles into recovery — the session-level pin
    /// on `.unresolved` routing through `enterRecovery` — and a manual
    /// result *during* recovery ends it (product decision, July 2026
    /// review): the game is decided, so the guidance no longer applies and
    /// is discarded; the finished game keeps its result and archives
    /// normally (headless here, so the draft carries it).
    @Test func resignDuringRecoveryEndsRecoveryAndKeepsTheDecidedGame() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())        // already-set-up → playing
        
        // A pawn materializing on e5 completes no legal move from the start
        // position: nothing was vacated, so reconstruction can't pair it
        // into a move and lands on `.unresolved`.
        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)
        #expect(session.needsRecovery == true)

        session.resign(.white)

        #expect(session.needsRecovery == false)
        #expect(session.liveGame?.isFinished == true)
        #expect(session.liveGame?.result == .blackWins)
    }
    
    /// The draw twin of the resign path above — both manual results share
    /// `normalizeModeForManualResult`.
    @Test func agreeDrawDuringRecoveryEndsRecoveryToo() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())
        
        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)
        #expect(session.needsRecovery == true)

        session.agreeDraw()
        
        #expect(session.needsRecovery == false)
        #expect(session.liveGame?.result == .draw)
    }
    
    // MARK: Illegal-Move Cue (M-ux.1)
    
    /// D13′ pinned at the session level: `onDesync` fires from
    /// `enterRecovery` — once per desync entry — and the manual-result
    /// recovery *exit* does not re-fire it. The audio behind the hook is
    /// waived transport; this spy is the whole witness the decision needs
    /// (the `onGameFinished`-on-finish shape).
    @Test func desyncFiresTheOnDesyncHookOnceAndTheExitDoesNot() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        var fired = 0
        session.onDesync = { fired += 1 }
        
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())        // already-set-up → playing
        
        // A pawn materializing on e5 completes no legal move from the
        // start position — the same unexplainable board the recovery
        // tests above use.
        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)
        #expect(session.needsRecovery == true)

        #expect(fired == 1)
        
        session.resign(.white)                        // recovery exit, not a desync
        #expect(session.needsRecovery == false)
        #expect(fired == 1)
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
    
    /// The core Decision #2 path: a committed ply lands in the file. Polls
    /// for the commit; the draft save is synchronous within the same settle.
    @Test func committedPlySavesTheDraft() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        let store = temporaryStore()
        session.draftStore = store
        
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())
        
        let e4 = try GameState.starting.parseSAN("e4")
        session.boardChanged(GameState.starting.applying(e4).position)
        try await settled(session)
        #expect(session.liveGame?.plyCount == 1)

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
    
    /// The stuck case the setup-time normalization exists for: a resumed
    /// mid-game draft's setup gate waits on its *mid-game* position, so
    /// resigning it instead of restoring the pieces must not leave the
    /// session waiting on a position nobody will ever rebuild. The result
    /// lands, the gate lifts, and the finished game lives in `playing`
    /// (whose settle branch watches for the start position — the pieces
    /// can be cleared freely). Headless, so the decided draft — not the
    /// Library — carries the result, as everywhere else in this suite.
    @Test func resignDuringResumeSetupEndsTheSetupWait() throws {
        let store = temporaryStore()
        let original = LiveGame(roster: roster())
        original.commit(try original.currentState.parseSAN("e4"))
        try store.save(original.draftSnapshot)
        
        let session = DGTLiveSession()
        session.draftStore = store
        session.loadPendingDraft()
        session.resumePendingDraft()                // no board seen → awaitingSetup
        #expect(session.awaitingPhysicalSetup == true)
        
        session.resign(.white)
        
        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.needsRecovery == false)
        #expect(session.liveGame?.isFinished == true)
        #expect(session.liveGame?.result == .blackWins)
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
    ///
    /// The suppression is a *negative*: awaiting the armed settle is what
    /// makes "the flag stayed down" meaningful — the settle has provably
    /// run before the flag is read. The breadcrumb it leaves in the
    /// session log is asserted too, pinning *which* branch suppressed the
    /// offer (the pending-draft guard, not an accident of timing).
    /// History, kept short: a fixed 450 ms sleep here was vacuously green
    /// if settle never ran; the breadcrumb poll that replaced it still
    /// returned silently on timeout.
    @Test func pendingDraftSuppressesTheNewGameOffer() async throws {
        let store = temporaryStore()
        let game = LiveGame(roster: roster())
        try store.save(game.draftSnapshot)
        
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        let log = DGTSessionLog()
        session.sessionLog = log
        session.draftStore = store
        session.loadPendingDraft()
        
        session.boardChanged(.starting)
        try await settled(session)
        #expect(log.entries.contains { $0.message.contains("offer suppressed") },
                "The suppressed settle should leave its breadcrumb")
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
    
    /// A finished-but-unarchived draft resumes with its manual result
    /// re-applied — the game comes back decided, not half-forgotten. This
    /// suite runs headless (nil `onGameFinished`), so no archive fires here;
    /// the wired self-heal path lives in `DGTLiveSessionArchiveTests`.
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
    // MARK: Board-Dump Resync (D49′)

    /// The `.unresolved` pre-flight: with the resync hook wired, the first
    /// unexplainable settle asks for a dump and stays in `playing` — no
    /// recovery, no desync record, and exactly one request.
    @Test func firstUnresolvedSettleAsksForADumpInsteadOfRecovery() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        var requests = 0
        session.requestBoardResync = { requests += 1 }
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())

        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)

        #expect(session.needsRecovery == false)
        #expect(requests == 1)
        #expect(session.liveGame != nil)
    }

    /// A board the dump-refreshed state still can't explain escalates for
    /// real — and does not ask twice: the second unresolved settle spends
    /// the debt rather than re-arming it, so recovery is always reachable.
    @Test func secondUnresolvedSettleEntersRecoveryWithoutAskingAgain() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        var requests = 0
        session.requestBoardResync = { requests += 1 }
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())

        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)          // defers, asks once
        session.boardChanged(garbage)       // the "dump" confirmed the garbage
        try await settled(session)

        #expect(session.needsRecovery == true)
        #expect(requests == 1)
    }

    /// An explained settle retires the one-shot debt, so a *later*
    /// divergence earns a fresh dump before recovery does — the debt is per
    /// divergence, not per game.
    @Test func anExplainedSettleReArmsTheResyncForTheNextDivergence() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        var requests = 0
        session.requestBoardResync = { requests += 1 }
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())

        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)          // defers, asks (1)
        session.boardChanged(.starting)     // dump answers: board was fine
        try await settled(session)          // .noChange — debt retired
        #expect(session.needsRecovery == false)

        session.boardChanged(garbage)       // a new divergence
        try await settled(session)
        #expect(session.needsRecovery == false)   // deferred again…
        #expect(requests == 2)                    // …with a fresh ask
        session.boardChanged(garbage)
        try await settled(session)
        #expect(session.needsRecovery == true)    // …and still escalates
    }

    /// The additive contract, pinned from the side that would break: with no
    /// hook — headless suites, unwired builds — `.unresolved` enters
    /// recovery on the first settle, exactly as before D49′. (The recovery
    /// suite above relies on this; here it is the *subject*.)
    @Test func unresolvedWithoutTheHookEntersRecoveryImmediately() async throws {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)
        session.boardChanged(.starting)
        session.startNewGame(roster: roster())

        var garbage = Position.starting
        garbage[Squares.e5] = .whitePawn
        session.boardChanged(garbage)
        try await settled(session)

        #expect(session.needsRecovery == true)
    }
}
