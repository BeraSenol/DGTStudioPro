//
//  DGTLiveSessionArchiveTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 06/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Coverage for the M5 archive flow on `DGTLiveSession`: the Library save
/// fires on the `isFinished` transition itself — from the auto-detected
/// result in settle, from `resign`/`agreeDraw`, and from resuming an
/// already-decided draft (the self-heal). Success (fresh or deduplicated)
/// retires the draft; failure keeps it and suppresses new-game entry until
/// `retryArchive()` succeeds or the player explicitly discards. A nil
/// `onGameFinished` hook means headless: no archive, the draft stays the
/// safety net — which is exactly why the pre-M5 suite still passes
/// unchanged.
///
/// Most tests wire a *real* `PGNStore` over an in-memory container, so the
/// session→store seam is exercised end to end; the failure tests use
/// `FlakyArchiveDoor` because a genuine SwiftData save failure can't be
/// forced deterministically.
///
/// Timing note: same convention as `DGTLiveSessionTests` — synchronous
/// tests hold the main actor so the quiescence `Task` never runs. The
/// settle-driven test shrinks `session.quiescence` to 10 ms (F7) and
/// *polls* for each commit (`poll(timeout:until:)`) rather than sleeping a
/// fixed interval: a fixed wait races the quiescence timer under
/// parallel-suite CPU load (the Perft suites saturate every core), and
/// losing that race cancels the pending settle and coalesces two moves
/// into an illegal diff — a test-only flake that looks exactly like a
/// session bug.
@MainActor
@Suite("DGT Live Session — Archive (M5)")
struct DGTLiveSessionArchiveTests {

    // MARK: Helpers

    private static func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private static func temporaryStore() -> LiveGameDraftStore {
        LiveGameDraftStore(
            directory: FileManager.default.temporaryDirectory
                .appending(path: UUID().uuidString)
        )
    }

    /// A pinned date so deduplication tests never straddle a midnight
    /// rollover (the content hash formats dates as yyyy.MM.dd in UTC).
    private static let fixedDate = Date(timeIntervalSince1970: 1_780_000_000)

    private static func roster(
        white: String = "Alice",
        black: String = "Bob"
    ) -> LiveGame.Roster {
        .init(
            event: "Club Night",
            site: "Home",
            date: fixedDate,
            round: 3,
            white: white,
            black: black
        )
    }

    /// A session wired like the app wires it: a temp-directory draft store
    /// and a *real* `PGNStore.archive` behind `onGameFinished`.
    private static func archivingSession(
        context: ModelContext
    ) -> (session: DGTLiveSession, drafts: LiveGameDraftStore) {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)   // F7 — see the timing note
        let drafts = temporaryStore()
        session.draftStore = drafts
        let store = PGNStore(modelContext: context)
        session.onGameFinished = { try store.archive($0) }
        return (session, drafts)
    }

    private static func libraryCount(in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<PGN>())
    }

    /// Waits for `condition` (up to `timeout`) instead of sleeping a fixed
    /// interval. The settle path is timer-driven — `boardChanged` cancels
    /// and restarts the quiescence task (shrunk to 10 ms here, F7) — so a
    /// fixed sleep races the
    /// scheduler: `Task.sleep` guarantees only a *minimum*, and a settle
    /// continuation can queue past any fixed window on a loaded machine,
    /// at which point the next board feed cancels it and two moves
    /// coalesce into one illegal diff. Waiting on the observable outcome
    /// makes scheduling delay extend the wait instead of failing the run.
    /// On timeout it simply returns — the `#expect` that follows then
    /// fails with the real value, which is the better diagnostic.
    private static func poll(
        timeout: Duration = .seconds(5),
        until condition: @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            if clock.now > deadline { return }
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    /// Awaits the armed quiescence task itself — the negative-assertion
    /// tool: after this returns, the settle has *definitely* run on the
    /// main actor, so "nothing changed" finally means something. The
    /// positive waits in this suite keep `poll` (each call site asserts
    /// the outcome right after, so a timeout fails there with the real
    /// value); the two fixed sleeps this helper replaced were the last
    /// waits that could pass without the settle ever running.
    private static func settled(_ session: DGTLiveSession) async throws {
        let armed = try #require(session.quiescenceTask)
        await armed.value
    }

    /// A controllable archive door for the failure paths: throws while
    /// `shouldFail`, otherwise delegates to the real store — so Retry can
    /// be tested as "the transient condition cleared".
    @MainActor
    private final class FlakyArchiveDoor {
        struct Failure: Swift.Error {}
        var shouldFail = true
        private let store: PGNStore
        init(store: PGNStore) { self.store = store }
        func archive(_ game: LiveGame) throws -> PGNStore.ArchiveResult {
            guard !shouldFail else { throw Failure() }
            return try store.archive(game)
        }
    }

    private static func flakySession(
        context: ModelContext
    ) -> (session: DGTLiveSession, drafts: LiveGameDraftStore, door: FlakyArchiveDoor) {
        let session = DGTLiveSession()
        session.quiescence = .milliseconds(10)   // F7 — see the timing note
        let drafts = temporaryStore()
        session.draftStore = drafts
        let door = FlakyArchiveDoor(store: PGNStore(modelContext: context))
        session.onGameFinished = { try door.archive($0) }
        return (session, drafts, door)
    }

    // MARK: Finish Paths — Success

    @Test func resignArchivesTheGameAndRetiresTheDraft() throws {
        let context = try Self.makeContext()
        let (session, drafts) = Self.archivingSession(context: context)
        session.startNewGame(roster: Self.roster())
        let game = try #require(session.liveGame)
        game.commit(try game.currentState.parseSAN("e4"))

        session.resign(.white)

        #expect(session.archiveOutcome == .archived)
        #expect(session.archivedPGN?.result == .blackWins)
        #expect(session.archivedPGN?.moves == ["e4"])
        #expect(try Self.libraryCount(in: context) == 1)
        // The game is safe in the Library — the draft's job is done.
        #expect(try drafts.load() == nil)
        // The finished game stays on screen (mode is still game-bearing).
        #expect(session.liveGame?.isFinished == true)
    }

    @Test func agreeDrawArchives() throws {
        let context = try Self.makeContext()
        let (session, drafts) = Self.archivingSession(context: context)
        session.startNewGame(roster: Self.roster())

        session.agreeDraw()

        #expect(session.archiveOutcome == .archived)
        #expect(session.archivedPGN?.result == .draw)
        #expect(try Self.libraryCount(in: context) == 1)
        #expect(try drafts.load() == nil)
    }

    /// End to end through the settle path: fool's mate on the board feed
    /// auto-detects the result, archives on the transition, retires the
    /// draft — then piece handling doesn't trip recovery (the pre-M5 seam),
    /// and the start position becomes the "play again" signal.
    @Test func mateArchivesAndTheStartPositionOffersTheNextGame() async throws {
        let context = try Self.makeContext()
        let (session, drafts) = Self.archivingSession(context: context)
        session.boardChanged(.starting)
        session.startNewGame(roster: Self.roster())   // already set up → playing

        var state = GameState.starting
        var states: [GameState] = []
        for san in ["f3", "e5", "g4", "Qh4"] {
            state = state.applying(try state.parseSAN(san))
            states.append(state)
        }
        for (index, reached) in states.enumerated() {
            session.boardChanged(reached.position)
            // Wait for THIS move to actually commit before feeding the
            // next board — see `poll`'s doc for why a fixed sleep here is
            // a load-dependent flake with this exact test's signature.
            try await Self.poll { session.liveGame?.sanMoves.count == index + 1 }
        }

        #expect(session.liveGame?.isFinished == true)
        #expect(session.liveGame?.result == .blackWins)
        #expect(session.archiveOutcome == .archived)
        #expect(try Self.libraryCount(in: context) == 1)
        #expect(try drafts.load() == nil)

        // Clearing pieces after the finish must not enter recovery…
        // Awaiting the armed settle replaces the old 100 ms fixed sleep:
        // the negative below is asserted after a settle that provably
        // ran, instead of hoping the margin covered it (it also retires
        // that comment's "coalesces under extreme load" caveat — there
        // is no window left to coalesce across).
        session.boardChanged(states[0].position)   // any mid-clear board
        try await Self.settled(session)
        #expect(session.needsRecovery == false)

        // …and restoring the start position offers the next game.
        session.boardChanged(.starting)
        try await Self.poll { session.shouldOfferNewGame }
        #expect(session.shouldOfferNewGame == true)
    }

    /// Requirement 8: a finished game that already exists in the Library
    /// (here: archived earlier by the store) deduplicates as *success*.
    @Test func finishingATwinDeduplicatesAsSuccess() throws {
        let context = try Self.makeContext()
        let store = PGNStore(modelContext: context)

        let twin = LiveGame(roster: Self.roster())
        twin.commit(try twin.currentState.parseSAN("e4"))
        twin.resign(.white)
        let seeded = try store.archive(twin)

        let (session, _) = Self.archivingSession(context: context)
        session.startNewGame(roster: Self.roster())
        let game = try #require(session.liveGame)
        game.commit(try game.currentState.parseSAN("e4"))
        session.resign(.white)

        #expect(session.archiveOutcome == .deduplicated)
        #expect(session.archivedPGN?.persistentModelID == seeded.pgn.persistentModelID)
        #expect(try Self.libraryCount(in: context) == 1)
    }

    // MARK: Finish Paths — Failure

    /// A failed archive keeps the draft *current* (it now carries the
    /// decided result, so a crash before Retry still self-heals at the next
    /// launch) and suppresses the new-game offer.
    @Test func failedArchiveKeepsTheDraftAndSuppressesTheOffer() async throws {
        let context = try Self.makeContext()
        let (session, drafts, _) = Self.flakySession(context: context)
        session.startNewGame(roster: Self.roster())

        session.resign(.white)

        guard case .failed = session.archiveOutcome else {
            Issue.record("Expected .failed, got \(String(describing: session.archiveOutcome))")
            return
        }
        #expect(session.archivedPGN == nil)
        #expect(try drafts.load()?.result == .blackWins)
        #expect(try Self.libraryCount(in: context) == 0)

        // The start position must NOT offer a new game while unresolved.
        // Awaiting the armed settle replaces the old 450 ms fixed sleep —
        // the suppressed settle has provably run when the flag is read.
        session.boardChanged(.starting)
        try await Self.settled(session)
        #expect(session.shouldOfferNewGame == false)
    }

    /// The suppression is structural: `startNewGame` refuses outright while
    /// the finished game hasn't reached the Library.
    @Test func failedArchiveRefusesANewGame() throws {
        let context = try Self.makeContext()
        let (session, _, _) = Self.flakySession(context: context)
        session.startNewGame(roster: Self.roster())
        session.resign(.white)

        session.startNewGame(roster: Self.roster(white: "Carol", black: "Dave"))

        #expect(session.liveGame?.roster.white == "Alice")
        #expect(session.liveGame?.isFinished == true)
        guard case .failed = session.archiveOutcome else {
            Issue.record("Expected the failure to survive the refused start")
            return
        }
    }

    @Test func retryAfterFailureArchivesAndLiftsTheSuppression() throws {
        let context = try Self.makeContext()
        let (session, drafts, door) = Self.flakySession(context: context)
        session.startNewGame(roster: Self.roster())
        session.resign(.white)
        guard case .failed = session.archiveOutcome else {
            Issue.record("Precondition: first archive attempt should fail")
            return
        }

        door.shouldFail = false
        session.retryArchive()

        #expect(session.archiveOutcome == .archived)
        #expect(try Self.libraryCount(in: context) == 1)
        #expect(try drafts.load() == nil)

        // Suppression lifted: a fresh game can begin.
        session.startNewGame(roster: Self.roster(white: "Carol", black: "Dave"))
        #expect(session.liveGame?.roster.white == "Carol")
        #expect(session.archiveOutcome == nil)
        #expect(session.archivedPGN == nil)
    }

    /// The other exit from a failed archive: the player explicitly discards
    /// (the inspector's existing destructive confirmation is the UI guard).
    @Test func discardAfterFailureClearsTheSuppression() throws {
        let context = try Self.makeContext()
        let (session, drafts, _) = Self.flakySession(context: context)
        session.startNewGame(roster: Self.roster())
        session.resign(.white)

        session.discardGame()

        #expect(session.liveGame == nil)
        #expect(session.archiveOutcome == nil)
        #expect(session.archivedPGN == nil)
        #expect(try drafts.load() == nil)
    }

    // MARK: Resume Self-Heal

    /// A decided draft means a previous run stopped between the finish and
    /// a successful save: resuming archives it immediately, skips the setup
    /// gate (nothing is left to track), and retires the file.
    @Test func resumingAFinishedDraftSelfHeals() throws {
        let context = try Self.makeContext()
        let drafts = Self.temporaryStore()
        let original = LiveGame(roster: Self.roster())
        original.commit(try original.currentState.parseSAN("e4"))
        original.resign(.white)
        try drafts.save(original.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = drafts
        let store = PGNStore(modelContext: context)
        session.onGameFinished = { try store.archive($0) }
        session.loadPendingDraft()
        session.resumePendingDraft()

        #expect(session.pendingDraft == nil)
        #expect(session.liveGame?.isFinished == true)
        #expect(session.awaitingPhysicalSetup == false)
        #expect(session.archiveOutcome == .archived)
        #expect(try Self.libraryCount(in: context) == 1)
        #expect(try drafts.load() == nil)
    }

    /// If the self-heal's archive also fails, the draft survives on disk —
    /// a finished game is never lost.
    @Test func selfHealFailureKeepsTheDraft() throws {
        let context = try Self.makeContext()
        let drafts = Self.temporaryStore()
        let original = LiveGame(roster: Self.roster())
        original.resign(.white)
        try drafts.save(original.draftSnapshot)

        let session = DGTLiveSession()
        session.draftStore = drafts
        let door = FlakyArchiveDoor(store: PGNStore(modelContext: context))
        session.onGameFinished = { try door.archive($0) }
        session.loadPendingDraft()
        session.resumePendingDraft()

        guard case .failed = session.archiveOutcome else {
            Issue.record("Expected .failed, got \(String(describing: session.archiveOutcome))")
            return
        }
        #expect(session.liveGame?.isFinished == true)
        #expect(try drafts.load()?.result == .blackWins)
        #expect(try Self.libraryCount(in: context) == 0)
    }

    // MARK: Acknowledgment

    /// Dismissing the confirmation sheet clears the *success* outcome (so
    /// it won't re-present) but keeps the archived row reachable for
    /// post-archive detail edits.
    @Test func acknowledgeClearsSuccessButKeepsTheRow() throws {
        let context = try Self.makeContext()
        let (session, _) = Self.archivingSession(context: context)
        session.startNewGame(roster: Self.roster())
        session.resign(.white)
        #expect(session.archiveOutcome == .archived)

        session.acknowledgeArchive()

        #expect(session.archiveOutcome == nil)
        #expect(session.archivedPGN != nil)
    }

    /// A failure can only be cleared by a successful retry or an explicit
    /// discard — never by evasion.
    @Test func acknowledgeDoesNotClearAFailure() throws {
        let context = try Self.makeContext()
        let (session, _, _) = Self.flakySession(context: context)
        session.startNewGame(roster: Self.roster())
        session.resign(.white)

        session.acknowledgeArchive()

        guard case .failed = session.archiveOutcome else {
            Issue.record("Expected the failure to survive acknowledgment")
            return
        }
    }

    // MARK: Headless (nil hook)

    /// With no `onGameFinished` wired — every pre-M5 unit test — finishing
    /// skips archiving and keeps the draft current: the safety net stands.
    @Test func headlessSessionKeepsTheDraft() throws {
        let session = DGTLiveSession()
        let drafts = Self.temporaryStore()
        session.draftStore = drafts
        session.startNewGame(roster: Self.roster())

        session.resign(.white)

        #expect(session.archiveOutcome == nil)
        #expect(session.archivedPGN == nil)
        #expect(try drafts.load()?.result == .blackWins)
    }

    // MARK: Post-Archive Edits

    /// Once archived, roster edits flow through the PGN door at the caller;
    /// the session must not resurrect a draft file for an archived game
    /// (it would re-offer an already-saved game at the next launch).
    @Test func rosterEditAfterArchiveDoesNotResurrectTheDraft() throws {
        let context = try Self.makeContext()
        let (session, drafts) = Self.archivingSession(context: context)
        session.startNewGame(roster: Self.roster())
        session.resign(.white)
        #expect(try drafts.load() == nil)

        session.updateRoster(Self.roster(white: "Carol", black: "Dave"))

        #expect(session.liveGame?.roster.white == "Carol")
        #expect(try drafts.load() == nil)
    }
}
