import Foundation
import os

/// Coordinates live play: watches the physical board (fed by `DGTConnection`), waits for
/// quiescence, runs the pure `DGTReconstructor` against the running `LiveGame`, commits
/// recognized moves. One private `Mode` is the single source of truth — every published flag is
/// derived, so they cannot contradict each other. Archive-first: a finished game is never lost.
@Observable
@MainActor
internal final class DGTLiveSession {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.dgt)
    
    // MARK: Mode
    
    /// The live-tracking mode — the single source of truth for `settle(_:)`. One enum, not flags,
    /// so illegal combinations are unrepresentable. Only `playing` runs reconstruction;
    /// `awaitingSetup` and `recovering` differ only in what exit they watch for.
    private enum Mode {
        case idle
        case awaitingSetup(LiveGame)
        case playing(LiveGame)
        case recovering(LiveGame)
    }
    
    /// A recognized move plus the physical correction that completes it (surfaced during `playing`).
    internal struct CorrectionHint: Equatable {
        /// The legal move that commits once the board is corrected.
        internal let move: Move
        /// Square(s) the player must clear (the un-lifted captured piece).
        internal let squares: [Square]
        /// A ready-to-display instruction (e.g. "Remove the captured pawn on e5…").
        internal let message: String
    }
    
    // MARK: Observable State
    
    /// Private; the published surface derives from it so the flags can never disagree with the mode.
    private var mode: Mode = .idle
    
    /// The running game, or nil when idle. Derived from `mode`.
    internal var liveGame: LiveGame? {
        switch mode {
        case .idle: nil
        case .awaitingSetup(let game), .playing(let game), .recovering(let game): game
        }
    }
    
    /// True after `startNewGame` while the physical board doesn't yet match the start position —
    /// reconstruction suppressed until the player sets up. Clears when a settled board matches.
    internal var awaitingPhysicalSetup: Bool {
        if case .awaitingSetup = mode { true } else { false }
    }
    
    /// True once a settled board matches no legal move and isn't a move in progress; recovery (D6)
    /// owns the UI. Clears when the board is restored, a new game starts, or the game is discarded.
    internal var needsRecovery: Bool {
        if case .recovering = mode { true } else { false }
    }
    
    /// Start position seen with no game running — the Board offers a new game. Its own flag, not a
    /// `Mode` case: it can only ever be an idle-time overlay.
    private(set) internal var shouldOfferNewGame = false
    
    /// Mid-castle: the un-placed rook's destination, rendered 50%-transparent. Set/cleared with
    /// `castlingGhostPiece` as a pair; non-nil iff a castle is mid-flight.
    private(set) internal var castlingGhostSquare: Square?
    
    /// The ghost piece — kept whole so `SquareView` stays ignorant of castling semantics.
    private(set) internal var castlingGhostPiece: Piece?
    
    /// A recognized move awaiting one simple physical fix (e.g. un-lifted en-passant pawn) — a
    /// gentle prompt, not the recovery flow. Transient settle-overlay like the ghost.
    private(set) internal var correctionHint: CorrectionHint?
    
    /// A draft found at launch, awaiting Resume / Delete — the only two options (Decision #3).
    /// `.corrupt` means the file can't be trusted; delete-only, file kept on disk as diagnostics.
    internal enum PendingDraft: Equatable {
        case resumable(LiveGameDraft)
        case corrupt
    }
    
    /// Non-nil while the Resume / Delete offer is on screen.
    private(set) internal var pendingDraft: PendingDraft?
    
    /// The decoded draft when `.resumable`, for the offer UI. Nil otherwise.
    internal var resumableDraft: LiveGameDraft? {
        if case .resumable(let draft) = pendingDraft { draft } else { nil }
    }
    
    /// True when a draft exists but can't be loaded — the delete-only offer variant.
    internal var pendingDraftIsCorrupt: Bool {
        pendingDraft == .corrupt
    }
    
    // MARK: Archive (M5)
    
    /// How the Library save went. Success (incl. dedup) drives the confirmation sheet; `failed`
    /// keeps the draft and suppresses new-game entry until retry succeeds or the player discards.
    private(set) internal var archiveOutcome: ArchiveOutcome?
    
    internal enum ArchiveOutcome: Equatable {
        /// Inserted fresh into the Library.
        case archived
        /// An identical game was already there — counts as success.
        case deduplicated
        /// The save failed; the draft is kept as the safety net.
        case failed(message: String)
    }
    
    /// The Library row the finished game landed on; survives `acknowledgeArchive()` so post-archive
    /// edits keep flowing until the next game replaces it.
    private(set) internal var archivedPGN: PGN?
    
    /// True while the last archive attempt failed — the new-game suppression flag.
    private var archiveFailed: Bool {
        if case .failed = archiveOutcome { true } else { false }
    }
    
    // MARK: Diagnostics
    
    /// Optional exportable diagnostic timeline; nil falls back to Console logging only.
    @ObservationIgnored internal var sessionLog: DGTSessionLog?
    
    /// Optional draft persistence; nil (headless tests) makes every save/load/delete a no-op.
    /// The session owns *when* drafts are written; the store owns the file.
    @ObservationIgnored internal var draftStore: LiveGameDraftStore?
    
    /// Optional archive door, keeping all Library I/O in `PGNStore`; nil means the draft stays the safety net.
    @ObservationIgnored internal var onGameFinished: ((LiveGame) throws -> PGNStore.ArchiveResult)?
    
    /// Illegal-move cue (D13′). Fired only by `enterRecovery` — the one door — so exactly once per
    /// desync entry: never on the manual-result exit, never on recomputation.
    @ObservationIgnored internal var onDesync: (() -> Void)?

    /// Board-resync request (D49′): the field stream is not lossless, and one lost update leaves
    /// `physicalBoard` wrong by one square forever. First `.unresolved` divergence asks for a full
    /// dump instead of entering recovery; nil hook = straight to recovery (pre-D49′, pinned).
    @ObservationIgnored internal var requestBoardResync: (() -> Void)?

    /// One shot per divergence; cleared by any explained settle and the lifecycle exits.
    /// Deliberately NOT cleared in `clearPlayingOverlays()` — that runs every settle and would re-arm forever.
    @ObservationIgnored private var resyncAttempted = false

    /// Board identity for `[Board "…"]` (D28′); consulted once per game in `startNewGame`.
    /// Capture-at-start survives cable pulls and crash-resume. Nil in headless tests.
    @ObservationIgnored internal var boardIdentity: (() -> String?)?

    // MARK: Private State
    
    /// The armed settle — readable so tests `await` the settle itself instead of polling wall clock
    /// (F7: fixed ceilings flake under a loaded ⌘U). Only `boardChanged` assigns it.
    @ObservationIgnored private(set) var quiescenceTask: Task<Void, Never>?
    
    /// Stillness window before reconstruction; 300 ms in production. Internal-settable for tests
    /// (F7); production code must never write it.
    @ObservationIgnored internal var quiescence: Duration = .milliseconds(300)
    /// Guards re-offering every quiescence while the board sits at the start.
    @ObservationIgnored private var offeredNewGameForCurrentStart = false
    /// Last observed physical board; `startNewGame` uses it to decide whether setup is needed.
    @ObservationIgnored private var lastObservedBoard: Position?
    
    internal init() {}
    
    // MARK: Board Feed
    
    /// Fed by `DGTConnection` on every change; restarts the quiescence window.
    internal func boardChanged(_ board: Position) {
        lastObservedBoard = board
        quiescenceTask?.cancel()
        quiescenceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.quiescence)
            guard !Task.isCancelled else { return }
            self.settle(board)
        }
    }
    
    // MARK: Settling
    
    /// Dispatches on mode; only `playing` runs reconstruction.
    private func settle(_ board: Position) {
        switch mode {
        case .idle:
            offerNewGameIfAtStart(board)
            
        case .awaitingSetup(let game):
            // Anything else is "still being set up" — not a desync, not a move.
            if board == game.currentState.position {
                mode = .playing(game)
                Self.logger?.info("Physical board reached new game's start, live play active")
                sessionLog?.capture(.info, "Physical setup complete, live play active")
            }
            
        case .playing(let game):
            if game.isFinished {
                // Finished: a terminal position explains no move, so clearing pieces would trip recovery with
                // no exit. The start position becomes the "play again" signal, same guards as idle.
                offerNewGameIfAtStart(board)
            } else {
                settlePlaying(game, board: board)
            }
            
        case .recovering(let game):
            // Recovery exit: board restored, resume play. While recovering, NO reconstruction or commit
            // runs — the previous design kept committing after entry and never left.
            if board == game.currentState.position {
                mode = .playing(game)
                clearGhost()
                Self.logger?.info("Board restored to last legal position, exiting recovery")
                sessionLog?.capture(.info, "Recovery resolved, board restored; resuming play")
            }
        }
    }
    
    /// Reconstruction dispatch — only reached while `playing`.
    private func settlePlaying(_ game: LiveGame, board: Position) {
        // Transient overlays are mutually exclusive and recomputed each settle: clear both, branch re-sets its own.
        clearPlayingOverlays()

        let outcome = DGTReconstructor.reconstruct(from: game.currentState, physical: board)

        // Any explained outcome retires the one-shot resync debt (D49′).
        if case .unresolved = outcome {} else { resyncAttempted = false }

        switch outcome {
        case .noChange:
            sessionLog?.capture(.debug, "settle: no change")
            
        case .inProgress:
            sessionLog?.capture(.debug, "settle: move in progress (pieces lifted, none placed)")
            
        case .castlingInProgress(let castling):
            // Castle mid-gesture: ghost the piece still in hand — rook in king-first, king when the rook landed first.
            setGhost(for: castling, physical: board)
            sessionLog?.capture(
                .info,
                "settle: castling in progress, ghost \(castlingGhostPiece?.type == .king ? "king" : "rook") awaited at \(castlingGhostSquare?.algebraicNotation ?? "?")"
            )
            
        case .correctable(let move, let clear, _):
            // Legal move, one physical correction remaining — a nudge, not a desync; `.move` commits once fixed.
            setCorrection(move: move, clear: clear, in: game.currentState)
            sessionLog?.capture(
                .info,
                "settle: correctable, clear \(clear.map(\.algebraicNotation).joined(separator: ",")) to complete \(game.currentState.san(for: move))"
            )
            
        case .move(let move):
            // Reconstructor verifies, `commit` re-checks — if the braces snap, proceeding would log a commit
            // that never happened and flag recovery one move late under a misleading breadcrumb (F5). Fail loudly.
            guard game.commit(move) else {
                recordError(
                    "settle: commit refused reconstructed move "
                    + "\(move.from.algebraicNotation)→\(move.to.algebraicNotation), entering recovery"
                )
                enterRecovery(game, board: board)
                return
            }
            sessionLog?.capture(
                .info,
                "settle: committed \(game.sanMoves.last ?? "?") [ply \(game.plyCount)]"
            )
            if game.isFinished {
                Self.logger?.info("Live game finished: \(game.result.rawValue, privacy: .public)")
                sessionLog?.capture(.info, "Live game finished: \(game.result.rawValue)")
                // Archive-first (M5): fires on the `isFinished` transition itself, before any UI reacts.
                archiveFinishedGame(game)
            } else {
                // Decision #2: the draft never trails the game by more than one event.
                saveDraft()
            }
            
        case .unresolved:
            // D49′: confirm against ground truth once before recovery. The F5 guard deliberately does NOT
            // route here — a logic divergence is not a lost-update symptom.
            escalateOrResync(game, board: board)
        }
    }

    /// The `.unresolved` gate (D49′): first divergence requests a dump and stays in `playing`;
    /// a board the dump still can't explain escalates for real. No hook: straight to recovery.
    private func escalateOrResync(_ game: LiveGame, board: Position) {
        guard let requestBoardResync else {
            enterRecovery(game, board: board)
            return
        }
        guard !resyncAttempted else {
            resyncAttempted = false
            enterRecovery(game, board: board)
            return
        }
        resyncAttempted = true
        Self.logger?.info("Settled board unexplained, requesting a full dump before recovery")
        sessionLog?.capture(
            .info,
            "settle: unreconciled, asking the board for a full dump before recovery (one shot)"
        )
        requestBoardResync()
    }
    
    /// The one door into `recovering` (both entries: `.unresolved` and the F5 guard). Captures the
    /// full-context desync when wired; terse Console breadcrumb when not.
    private func enterRecovery(_ game: LiveGame, board: Position) {
        mode = .recovering(game)
        // D13′: the cue rides the mode transition, so it can never drift from the derived flags.
        onDesync?()
        if let sessionLog {
            sessionLog.recordDesync(
                before: game.currentState,
                physical: board,
                recentSAN: game.sanMoves,
                plyCount: game.plyCount
            )
        } else {
            Self.logger?.error("Board could not be reconciled, entering recovery")
        }
    }
    
    private func offerNewGameIfAtStart(_ board: Position) {
        if board == .starting {
            // A pending resume offer outranks the new-game offer — starting fresh would overwrite the very
            // draft being offered. A failed archive suppresses too: the game must reach the Library or be
            // explicitly discarded.
            if !offeredNewGameForCurrentStart && pendingDraft == nil && !archiveFailed {
                shouldOfferNewGame = true
                offeredNewGameForCurrentStart = true
                Self.logger?.info("Start position detected, offering new game")
                sessionLog?.capture(.info, "Start position detected, offering new game")
            } else {
                // The suppressed settle leaves a breadcrumb — a positive signal tests can await (F7).
                let reason = pendingDraft != nil ? "resume offer pending"
                : archiveFailed ? "unarchived finished game"
                : "already offered for this visit to the start"
                sessionLog?.capture(.debug, "Start position settled, new-game offer suppressed (\(reason))")
            }
        } else {
            offeredNewGameForCurrentStart = false
        }
    }
    
    // MARK: Game Lifecycle
    
    /// Begins a new live game (only one unfinished game exists at a time). Skips the setup gate
    /// when the physical board already matches the start.
    internal func startNewGame(roster: LiveGame.Roster) {
        // A failed archive suppresses new-game entry structurally: starting fresh would overwrite the
        // finished game's only safety net.
        guard !archiveFailed else {
            recordError(
                "New game refused: the finished game hasn't been saved yet, retry or discard first"
            )
            return
        }
        
        // D28′: stamp board identity at game start — the one write to `Roster.board`, unconditional.
        var roster = roster
        roster.board = boardIdentity?()

        let game = LiveGame(roster: roster)
        archiveOutcome = nil
        archivedPGN = nil
        shouldOfferNewGame = false
        offeredNewGameForCurrentStart = true
        resyncAttempted = false   // a fresh game owes no dump debt (D49′)
        clearPlayingOverlays()
        
        let alreadySetUp = beginTracking(game)
        
        sessionLog?.record(
            .info,
            "New live game: \(roster.white) vs \(roster.black)"
            + (alreadySetUp ? "" : ", awaiting physical setup")
        )
        if !alreadySetUp {
            Self.logger?.info("New game started, awaiting physical setup of starting position")
        }
        
        // Starting fresh forfeits any resume offer (the sheet's destructive confirmation guards that);
        // the roster-only snapshot claims the file for the new game.
        pendingDraft = nil
        saveDraft()
    }
    
    /// Dismisses the offer (no re-prompt until the board leaves and returns to the start).
    internal func dismissNewGameOffer() {
        shouldOfferNewGame = false
        sessionLog?.capture(.debug, "New-game offer dismissed")
    }
    
    /// Discards the current live game and returns to idle.
    internal func discardGame() {
        mode = .idle
        clearPlayingOverlays()
        resyncAttempted = false   // the debt dies with the game (D49′)
        offeredNewGameForCurrentStart = false
        // Explicit-Discard exit from a failed archive: the player chose to lose the game.
        archiveOutcome = nil
        archivedPGN = nil
        // A discarded game must not resurrect as a resume offer — Decision #3's delete path ends on disk too.
        pendingDraft = nil
        draftStore?.delete()
        sessionLog?.capture(.info, "Live game discarded")
    }
    
    // MARK: Manual Result Passthrough
    
    internal func resign(_ color: PieceColor) {
        guard let game = liveGame, !game.isFinished else { return }
        game.resign(color)
        sessionLog?.capture(.info, "Manual result: \(color) resigned")
        normalizeModeForManualResult()
        archiveFinishedGame(game)   // archive-first on the finish transition (M5)
    }
    
    internal func agreeDraw() {
        guard let game = liveGame, !game.isFinished else { return }
        game.agreeDraw()
        sessionLog?.capture(.info, "Manual result: draw agreed")
        normalizeModeForManualResult()
        archiveFinishedGame(game)   // archive-first on the finish transition (M5)
    }
    
    /// A manual result ends any non-`playing` tracking mode: the game is decided, so no recovery or
    /// setup target exists — the board no longer owes the session a position. `playing` is where
    /// finished games live (its settle only watches for the "play again" start position).
    private func normalizeModeForManualResult() {
        switch mode {
        case .idle, .playing:
            return
        case .recovering(let game):
            mode = .playing(game)
            sessionLog?.capture(.info, "Recovery ended by manual result, guidance discarded")
        case .awaitingSetup(let game):
            mode = .playing(game)
            sessionLog?.capture(.info, "Setup wait ended by manual result, nothing left to set up")
        }
        // Defensive: neither mode can have set these; keeps the exit symmetrical.
        clearPlayingOverlays()
    }
    
    // MARK: Roster
    
    /// Replaces the roster wholesale. Routed through the session so the timeline gets a breadcrumb
    /// and draft persistence has one choke point. No-op while idle.
    internal func updateRoster(_ roster: LiveGame.Roster) {
        guard let liveGame else { return }
        liveGame.roster = roster
        sessionLog?.record(
            .info,
            "Roster updated: \(roster.white) vs \(roster.black)"
        )
        // Draft-worthy (Decision #2) — but once archived the draft is gone and edits flow through the
        // PGN door; resurrecting one here would re-offer an archived game at next launch.
        if archivedPGN == nil {
            saveDraft()
        }
    }
    
    // MARK: Archive (M5)
    
    /// The archive-first choke point: every `isFinished` transition plus the resume self-heal.
    /// No hook: the draft stays current as the safety net.
    private func archiveFinishedGame(_ game: LiveGame) {
        // Decision #3: no `*` result ever archives — structural, not just implied by `isFinished`.
        guard game.isFinished, game.result != .ongoing else { return }
        // Already archived (stray repeat call) — nothing to do.
        guard archivedPGN == nil else { return }
        
        guard let onGameFinished else {
            saveDraft()
            return
        }
        
        do {
            let result = try onGameFinished(game)
            archivedPGN = result.pgn
            archiveOutcome = result.deduplicated ? .deduplicated : .archived
            // The draft's job is done; leaving it would re-offer an archived game at next launch.
            draftStore?.delete()
            // Buffer-only (`capture`): PGNStore already Console-logs the archive. The failure arm uses
            // `record` — PGNStore threw before logging, so the session is the sole Console witness.
            sessionLog?.capture(
                .info,
                result.deduplicated
                ? "Archive deduplicated: '\(result.pgn.name)' already in the Library"
                : "Archived to Library: '\(result.pgn.name)' [\(game.result.rawValue)]"
            )
        } catch {
            archiveOutcome = .failed(message: error.localizedDescription)
            archivedPGN = nil
            saveDraft()
            recordError(
                "Archive failed: \(error). Draft kept, new-game entry suppressed until Retry or Discard"
            )
        }
    }
    
    /// Retries a failed archive (the HUD's Retry). No-op unless the last attempt failed.
    internal func retryArchive() {
        guard case .failed = archiveOutcome,
              let game = liveGame, game.isFinished else { return }
        sessionLog?.record(.info, "Retrying archive…")
        archiveFinishedGame(game)
    }
    
    /// Dismisses the confirmation. Clears a *success* only — a failure clears exclusively by a
    /// successful retry or explicit discard, never by evasion. `archivedPGN` survives for edits.
    internal func acknowledgeArchive() {
        switch archiveOutcome {
        case .archived, .deduplicated:
            archiveOutcome = nil
        case .failed, nil:
            break
        }
    }
    
    // MARK: Draft Persistence (M4)
    
    /// Loads any leftover draft into `pendingDraft` (once, from `App.init()`). A file that exists
    /// but can't load surfaces as `.corrupt` — the player decides; the file stays as diagnostics.
    internal func loadPendingDraft() {
        guard let draftStore else { return }
        do {
            guard let draft = try draftStore.load() else { return }
            pendingDraft = .resumable(draft)
            sessionLog?.record(
                .info,
                "Draft found: \(draft.white) vs \(draft.black) "
                + "(\(draft.sanMoves.count) plies), offering resume"
            )
        } catch {
            pendingDraft = .corrupt
            recordError("Draft file can't be read: \(error), offering delete")
        }
    }
    
    /// Replays the draft's SAN through `LiveGame(resuming:)`; then the same setup gate as a fresh
    /// game, against the game's *current* position. Replay failure → `.corrupt`.
    internal func resumePendingDraft() {
        guard case .resumable(let draft) = pendingDraft else { return }
        do {
            let game = try LiveGame(resuming: draft)
            pendingDraft = nil
            shouldOfferNewGame = false
            offeredNewGameForCurrentStart = true
            clearPlayingOverlays()
            
            if game.isFinished {
                // Self-heal (M5): a decided draft means a previous run stopped between finish and save.
                // No setup gate — nothing left to track; dedup makes a double-heal harmless.
                mode = .playing(game)
                sessionLog?.record(
                    .info,
                    "Resumed a finished game (\(draft.result.rawValue)), archiving now"
                )
                archiveFinishedGame(game)
            } else {
                let alreadySetUp = beginTracking(game)
                
                sessionLog?.record(
                    .info,
                    "Resumed live game: \(draft.white) vs \(draft.black) (\(game.plyCount) plies)"
                    + (alreadySetUp ? "" : ", awaiting physical setup")
                )
            }
        } catch {
            pendingDraft = .corrupt
            recordError("Draft failed to resume: \(error), offering delete")
        }
    }
    
    /// Deletes the draft (declined or corrupt); if the board sits at the start, the ordinary
    /// new-game offer takes over on the spot.
    internal func deletePendingDraft() {
        guard pendingDraft != nil else { return }
        pendingDraft = nil
        draftStore?.delete()
        sessionLog?.record(.info, "Pending draft deleted")
        if case .idle = mode, let board = lastObservedBoard {
            offerNewGameIfAtStart(board)
        }
    }
    
    /// Snapshot after every committed ply, manual result, roster edit, and game start. Failures log
    /// loudly but never interrupt play — the next event retries.
    private func saveDraft() {
        guard let game = liveGame, let draftStore else { return }
        do {
            try draftStore.save(game.draftSnapshot)
        } catch {
            recordError("Draft save failed: \(error)")
        }
    }
    
    // MARK: Private — Ghost
    
    /// Both ghost fields together for a mid-castle: the settled board tells which piece is airborne
    /// (rook already home ⇒ the king is in hand).
    private func setGhost(for castling: Move, physical: Position) {
        let rook = Piece(castling.pieceColor, .rook)
        if let rookTo = castling.rookTo, physical[rookTo] != rook {
            castlingGhostSquare = rookTo
            castlingGhostPiece = rook
        } else {
            castlingGhostSquare = castling.to
            castlingGhostPiece = Piece(castling.pieceColor, .king)
        }
    }
    
    /// Clears both ghost fields — always set and cleared as a pair.
    private func clearGhost() {
        castlingGhostSquare = nil
        castlingGhostPiece = nil
    }
    
    /// The transient overlays as one unit, so a third overlay is added in one place. The recovery
    /// exit keeps the narrower `clearGhost()` — a correction hint can't survive into recovery.
    private func clearPlayingOverlays() {
        clearGhost()
        correctionHint = nil
    }
    
    /// Straight to `playing` when the pieces already stand where the game expects, else the setup
    /// gate. One home for the question a fresh game and a resumed draft both ask.
    @discardableResult
    private func beginTracking(_ game: LiveGame) -> Bool {
        let alreadySetUp = lastObservedBoard == game.currentState.position
        mode = alreadySetUp ? .playing(game) : .awaitingSetup(game)
        return alreadySetUp
    }
    
    /// An error that must reach somewhere: the timeline when wired, Console when not.
    private func recordError(_ message: String) {
        if let sessionLog {
            sessionLog.record(.error, message)
        } else {
            Self.logger?.error("\(message, privacy: .public)")
        }
    }
    
    /// Builds the pending correction hint for a recognized-but-incomplete move.
    private func setCorrection(move: Move, clear: [Square], in state: GameState) {
        let squares = clear.map(\.algebraicNotation).joined(separator: ", ")
        let noun = clear.count == 1 ? "pawn" : "pawns"
        correctionHint = CorrectionHint(
            move: move,
            squares: clear,
            message: "Remove the captured \(noun) on \(squares) to complete \(state.san(for: move))."
        )
    }
}
