//
//  DGTLiveSession.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 26/05/2026.
//

import Foundation
import os

/// Coordinates live play: it watches the physical board (fed from
/// `DGTConnection`), waits for the board to settle, runs the pure
/// `DGTReconstructor` against the running `LiveGame`, and commits recognized
/// moves. App-global and `@Observable`, injected like `DGTConnection`.
///
/// The quiescence window (300 ms in production; see `quiescence`) is the one
/// piece of timing the pure engine
/// can't own: a single move arrives as several field updates, so the session
/// restarts a timer on every board change and only attempts reconstruction
/// once the board has been still long enough that the player's hand has left
/// it. This is the boundary the roadmap draws — "the live model owns all
/// mutable state," the classifier stays pure.
///
/// ## State model
///
/// The session is a small state machine. Its mutually-exclusive live-tracking
/// modes are a single private `Mode` enum (the single source of truth), and
/// the published flags the UI reads (`liveGame`, `awaitingPhysicalSetup`,
/// `needsRecovery`) are *derived* from it, so they can never contradict each
/// other. (The previous design tracked these as independent
/// booleans/optionals, which permitted nonsense like "recovering AND awaiting
/// setup," let recovery be entered with no way to leave it, and kept running
/// reconstruction after a desync.)
///
/// What it exposes for the UI: `liveGame` (the running game),
/// `shouldOfferNewGame` (start position seen with no game → present the
/// new-game dialog), `castlingGhostSquare` + `castlingGhostPiece` (render a
/// 50%-ghost piece here mid-castle), `needsRecovery` (the board can't be
/// explained → D6 takes over), and `awaitingPhysicalSetup` (a new game has
/// been started but the pieces don't match its starting position yet — the UI
/// should prompt for setup rather than show recovery). From M4 it also
/// exposes `pendingDraft` — a crash-safety draft found on disk at launch,
/// awaiting the player's Resume / Delete decision — and persists the running
/// game through `draftStore` after every committed ply and every
/// result/roster change. From M5 a finished game archives into the Library
/// on the `isFinished` transition itself (archive-first, before any UI) via
/// the `onGameFinished` hook; `archiveOutcome` publishes how it went, and a
/// failed archive keeps the draft and suppresses new-game entry until Retry
/// or an explicit Discard — a finished game is never lost.
///
/// Diagnostics: settle outcomes, lifecycle transitions, and — critically — a
/// full-context desync capture are routed into the optional `sessionLog`
/// (`DGTSessionLog`), the same additive settable-hook pattern as
/// `DGTConnection.onBoardChanged`. Existing Console logging is unchanged.
@Observable
@MainActor
internal final class DGTLiveSession {
    
    // MARK: Static Constants
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "dgt"
    )
    
    // MARK: Mode
    
    /// The session's live-tracking mode — the single source of truth for what
    /// `settle(_:)` does. Modeling these as one enum (rather than separate
    /// flags) makes illegal combinations unrepresentable.
    ///
    /// - `idle`: no game in progress. `settle` only watches for the start
    ///   position to offer a new game.
    /// - `awaitingSetup`: a game has been created but the physical pieces
    ///   don't match its starting position yet. Reconstruction is suppressed
    ///   until the board matches; the UI prompts for setup.
    /// - `playing`: a game is running and each settled board is reconstructed
    ///   into moves.
    /// - `recovering`: a settled board couldn't be explained by any legal move
    ///   (D6 territory). Reconstruction is suppressed; the session waits for
    ///   the board to be restored to the last legal position — that match is
    ///   the exit condition.
    ///
    /// `awaitingSetup` and `recovering` share the same exit predicate (the
    /// board matching `game.currentState.position`); they differ only in what
    /// the UI says and how they were entered.
    private enum Mode {
        case idle
        case awaitingSetup(LiveGame)
        case playing(LiveGame)
        case recovering(LiveGame)
    }
    
    /// A recognized move plus the physical correction the player must make to
    /// complete it — surfaced as `correctionHint` during `playing`.
    internal struct CorrectionHint: Equatable {
        /// The legal move that commits once the board is corrected.
        internal let move: Move
        /// Square(s) the player must clear (the un-lifted captured piece).
        internal let squares: [Square]
        /// A ready-to-display instruction (e.g. "Remove the captured pawn on e5…").
        internal let message: String
    }
    
    // MARK: Observable State
    
    /// The live-tracking mode. Private; the published surface below derives
    /// from it so the flags can never disagree with the mode.
    private var mode: Mode = .idle
    
    /// The running game, or nil when idle. Derived from `mode`.
    internal var liveGame: LiveGame? {
        switch mode {
        case .idle: nil
        case .awaitingSetup(let game), .playing(let game), .recovering(let game): game
        }
    }
    
    /// True after `startNewGame` when the physical board doesn't (yet) match
    /// the new game's starting position. While set, reconstruction is
    /// suppressed — no commits, no recovery — and the session waits for the
    /// player to physically set up the pieces. Clears automatically once a
    /// settled board matches the game's start.
    ///
    /// Without this, starting a new game while the previous game's final
    /// position is still on the board would diff hugely against the new game's
    /// start, match no legal move, and trip recovery on the first quiescence.
    /// The new-game dialog typically appears *because* the start was already
    /// detected, so in the common path this is false from the moment the game
    /// is created. Derived from `mode`.
    internal var awaitingPhysicalSetup: Bool {
        if case .awaitingSetup = mode { true } else { false }
    }
    
    /// True once a settled board matches no legal move and isn't a move in
    /// progress — the unified recovery system (D6) owns the UI from here.
    /// Clears automatically when the board is restored to the last legal
    /// position (or when a new game starts / the game is discarded). Derived
    /// from `mode`.
    internal var needsRecovery: Bool {
        if case .recovering = mode { true } else { false }
    }
    
    /// Set when the standard start position is detected with no game running,
    /// so the Board UI can offer to start a new game. Cleared on dismissal,
    /// when a game starts, or when the board moves away from the start.
    ///
    /// Kept as its own flag (not a `Mode` case) deliberately: it's only ever
    /// meaningful while idle, it's purely an "offer pending" hint for the
    /// dialog, and folding it into `Mode` would entangle the offer/dismiss
    /// debounce with the live-tracking modes for no real safety gain.
    private(set) internal var shouldOfferNewGame = false
    
    /// During a castle whose rook hasn't yet been placed, the rook's
    /// destination square — the Board renders a 50%-transparent rook there
    /// (via `castlingGhostPiece`) until the real rook lands. Both fields are
    /// set and cleared together (`setGhost`/`clearGhost`); non-nil iff a castle
    /// is mid-flight during `playing`.
    private(set) internal var castlingGhostSquare: Square?
    
    /// The piece to render at `castlingGhostSquare`. Always a rook of the
    /// moving side. Kept as a full `Piece` so `SquareView` can stay ignorant of
    /// castling semantics and simply render whatever ghost piece it's handed.
    private(set) internal var castlingGhostPiece: Piece?
    
    /// A pending soft-correction: a legal move is recognized but the board needs
    /// one simple fix (e.g. an en-passant capture whose taken pawn wasn't
    /// lifted). Non-nil while a correction is awaited during `playing`; the UI
    /// should show `message` as a gentle prompt rather than the recovery flow.
    /// Set and cleared as a transient settle-overlay, like the castling ghost.
    private(set) internal var correctionHint: CorrectionHint?
    
    /// A draft found on disk at launch, awaiting the player's Resume / Delete
    /// decision (Decision #3: those are the only two options — no
    /// archive-unfinished path exists anywhere). `resumable` carries the
    /// decoded draft so the offer can describe the game; `corrupt` means a
    /// file exists but can't be trusted — unreadable, undecodable, an unknown
    /// schema, or a transcript this build's rules can't reproduce — and the
    /// only offer is deletion (the file stays on disk as diagnostics until
    /// the player decides).
    internal enum PendingDraft: Equatable {
        case resumable(LiveGameDraft)
        case corrupt
    }
    
    /// Non-nil while a Resume / Delete offer should be on screen. Set by
    /// `loadPendingDraft()` during app wiring; cleared by resuming, deleting,
    /// or starting a new game (which overwrites the file anyway).
    private(set) internal var pendingDraft: PendingDraft?
    
    /// The decoded draft when `pendingDraft` is `.resumable`, for the offer
    /// UI to describe (players, ply count, last-saved date). Nil otherwise.
    internal var resumableDraft: LiveGameDraft? {
        if case .resumable(let draft) = pendingDraft { draft } else { nil }
    }
    
    /// True when a draft file exists but can't be loaded or replayed — the
    /// offer UI shows the delete-only variant.
    internal var pendingDraftIsCorrupt: Bool {
        pendingDraft == .corrupt
    }
    
    // MARK: Archive (M5)
    
    /// How the finished game's Library save went. Success (`archived` /
    /// `deduplicated` — a hash match is success too, requirement 8) drives
    /// the confirmation/edit sheet; `failed` keeps the draft on disk and
    /// suppresses new-game entry until `retryArchive()` succeeds or the
    /// player explicitly discards. Nil while no finished game awaits, or
    /// after a success is acknowledged.
    private(set) internal var archiveOutcome: ArchiveOutcome?
    
    internal enum ArchiveOutcome: Equatable {
        /// Inserted fresh into the Library.
        case archived
        /// An identical game was already there — counts as success.
        case deduplicated
        /// The save failed; the draft is kept as the safety net.
        case failed(message: String)
    }
    
    /// The Library row the finished game landed on (fresh or deduplicated),
    /// for the confirmation sheet and post-archive detail edits. Survives
    /// `acknowledgeArchive()` — the player can keep editing details from
    /// the inspector until the next game replaces it. Nil while unarchived.
    private(set) internal var archivedPGN: PGN?
    
    /// True while the last archive attempt failed — the suppression flag
    /// behind the new-game guards.
    private var archiveFailed: Bool {
        if case .failed = archiveOutcome { true } else { false }
    }
    
    // MARK: Diagnostics
    
    /// Optional exportable diagnostic timeline. Wired by the app
    /// (`session.sessionLog = log`); when nil, the session falls back to its
    /// own Console logger and nothing else changes.
    @ObservationIgnored internal var sessionLog: DGTSessionLog?
    
    /// Optional draft persistence (M4). Wired by the app
    /// (`session.draftStore = store`) with the same settable-hook pattern as
    /// `sessionLog`; when nil — unit tests that don't exercise persistence —
    /// every save/load/delete below is a silent no-op. The session owns
    /// *when* drafts are written; the store owns the file.
    @ObservationIgnored internal var draftStore: LiveGameDraftStore?
    
    /// Optional archive door (M5). Wired by the app
    /// (`session.onGameFinished = { try pgnStore.archive($0) }`) — the same
    /// settable-hook pattern as `sessionLog`/`draftStore`, keeping all
    /// Library I/O in `PGNStore`. When nil — headless unit tests — no
    /// archive fires and the draft stays the safety net.
    @ObservationIgnored internal var onGameFinished: ((LiveGame) throws -> PGNStore.ArchiveResult)?
    
    /// Optional illegal-move cue (M-ux.1, D13′). Invoked by `enterRecovery`
    /// — the one door into `recovering` and the one `recordDesync` site —
    /// so it fires exactly once per desync entry: never on the manual-result
    /// recovery exit, never on flag recomputation. Wired once in
    /// `App.init()` (system alert, gated there by the Settings toggle and
    /// the UI-test seed); when nil — unit tests — the session is silent,
    /// headless by construction. Rejected: a view observing `needsRecovery`
    /// (couples the board surface to audio and re-fires on both exits).
    @ObservationIgnored internal var onDesync: (() -> Void)?

    /// Optional board-identity source (M2, D28′) — answers "which physical
    /// board is this?" as a ready-made `[Board "…"]` tag value. Wired once
    /// in `App.init()` to `connection.boardInfo.identityTag`; consulted
    /// exactly once per game, in `startNewGame`, which stamps the answer
    /// onto `Roster.board` (see that doc for why capture-at-start beats
    /// read-at-archive). The same settable-hook pattern as its siblings —
    /// the session never imports the connection — and nil in headless unit
    /// tests, where games simply carry no board, like pre-M2 archives.
    @ObservationIgnored internal var boardIdentity: (() -> String?)?

    // MARK: Private State
    
    /// The armed settle. Readable — never writable — outside the type so
    /// tests can `await` the settle itself instead of polling a wall clock
    /// for its side effects (F7). Under a full ⌘U a dozen `@MainActor`
    /// suites share one actor, so a 10 ms timer lags arbitrarily and any
    /// fixed ceiling is a guess that a loaded machine eventually beats;
    /// awaiting the task makes scheduling delay extend the wait instead of
    /// failing the run. Only `boardChanged` assigns it.
    @ObservationIgnored private(set) var quiescenceTask: Task<Void, Never>?
    
    /// The stillness window between the last field update and a
    /// reconstruction attempt — long enough that the player's hand has left
    /// the board, short enough to feel instant. 300 ms in production.
    /// Internal-settable so tests shrink it to a few milliseconds and poll
    /// on outcomes instead of sleeping wall-clock margins (F7 — the fixed
    /// 450 ms waits raced the scheduler under parallel-suite load, a
    /// test-only flake with a session-bug signature). Production code must
    /// never write it.
    @ObservationIgnored internal var quiescence: Duration = .milliseconds(300)
    /// Guards against re-offering a new game every quiescence while the board
    /// sits at the start position; reset when the board leaves the start.
    @ObservationIgnored private var offeredNewGameForCurrentStart = false
    /// The most recently observed physical board, used by `startNewGame` to
    /// decide whether `awaitingSetup` is needed (i.e. whether the pieces are
    /// already at the game's start position). Nil until the first board update.
    @ObservationIgnored private var lastObservedBoard: Position?
    
    internal init() {}
    
    // MARK: Board Feed
    
    /// Fed by `DGTConnection` on every physical board change. Restarts the
    /// quiescence window — reconstruction only runs once updates stop.
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
    
    /// Dispatches on the current mode. Each game-bearing mode owns its own
    /// settle behavior; only `playing` runs reconstruction.
    private func settle(_ board: Position) {
        switch mode {
        case .idle:
            offerNewGameIfAtStart(board)
            
        case .awaitingSetup(let game):
            // Suppress reconstruction until the physical pieces match the new
            // game's start. Anything else is "still being set up" — not a
            // desync, not a move.
            if board == game.currentState.position {
                mode = .playing(game)
                Self.logger.info("Physical board reached new game's start — live play active")
                sessionLog?.capture(.info, "Physical setup complete — live play active")
            }
            
        case .playing(let game):
            if game.isFinished {
                // The game is over: no reconstruction. A terminal position
                // explains no further move, so clearing the pieces would
                // otherwise diff to `.unresolved` and trip recovery with no
                // exit (the pre-M5 seam). Instead the finished game stays on
                // screen and the start position becomes the "play again"
                // signal, exactly as in idle — with the same suppression
                // guards inside `offerNewGameIfAtStart`.
                offerNewGameIfAtStart(board)
            } else {
                settlePlaying(game, board: board)
            }
            
        case .recovering(let game):
            // Recovery exit: the board has been restored to the last legal
            // position, so resume play. D6 owns the *presentation* (graying,
            // per-square guidance, an arrow back to the legal position); this
            // owns the *exit condition*. While recovering, NO reconstruction
            // or commit runs — the previous design kept committing moves after
            // entering recovery and never left it.
            if board == game.currentState.position {
                mode = .playing(game)
                clearGhost()
                Self.logger.info("Board restored to last legal position — exiting recovery")
                sessionLog?.capture(.info, "Recovery resolved — board restored; resuming play")
            }
        }
    }
    
    /// Reconstruction dispatch — only reached while `playing`.
    private func settlePlaying(_ game: LiveGame, board: Position) {
        // Transient playing-overlays (ghost rook, correction hint) are mutually
        // exclusive and recomputed each settle: clear both up front, then the
        // relevant branch re-sets its own.
        clearPlayingOverlays()
        
        switch DGTReconstructor.reconstruct(from: game.currentState, physical: board) {
        case .noChange:
            sessionLog?.capture(.debug, "settle: no change")
            
        case .inProgress:
            sessionLog?.capture(.debug, "settle: move in progress (pieces lifted, none placed)")
            
        case .castlingInProgress(let castling):
            // A castle is mid-gesture; ghost the piece still in the player's
            // hand on its destination — the rook in king-first castling, the
            // king when a two-handed castle's rook lands first.
            setGhost(for: castling, physical: board)
            sessionLog?.capture(
                .info,
                "settle: castling in progress — ghost \(castlingGhostPiece?.type == .king ? "king" : "rook") awaited at \(castlingGhostSquare?.algebraicNotation ?? "?")"
            )
            
        case .correctable(let move, let clear, _):
            // A legal move is recognized but one physical correction remains
            // (e.g. an en-passant capture whose taken pawn wasn't lifted). A
            // gentle nudge, not a desync — show a hint and stay in `playing`;
            // the `.move` branch commits automatically once the board is fixed.
            setCorrection(move: move, clear: clear, in: game.currentState)
            sessionLog?.capture(
                .info,
                "settle: correctable — clear \(clear.map(\.algebraicNotation).joined(separator: ",")) to complete \(game.currentState.san(for: move))"
            )
            
        case .move(let move):
            // The reconstructor only hands over moves it verified against
            // `legalMoves()`, and `commit` re-checks — belt and braces. If
            // the braces ever snap (a logic divergence between the two),
            // proceeding as if the move landed would log a commit that
            // never happened, snapshot an unchanged draft, and leave the
            // *next* settle to flag recovery one move late under a
            // misleading breadcrumb (F5). Fail loudly, on the spot.
            guard game.commit(move) else {
                recordError(
                    "settle: commit refused reconstructed move "
                    + "\(move.from.algebraicNotation)→\(move.to.algebraicNotation) — entering recovery"
                )
                enterRecovery(game, board: board)
                return
            }
            sessionLog?.capture(
                .info,
                "settle: committed \(game.sanMoves.last ?? "?") [ply \(game.plyCount)]"
            )
            if game.isFinished {
                Self.logger.info("Live game finished: \(game.result.rawValue, privacy: .public)")
                sessionLog?.capture(.info, "Live game finished: \(game.result.rawValue)")
                // Archive-first (M5): the Library save fires on the
                // `isFinished` transition itself, before any UI reacts.
                // Success retires the draft; failure keeps it current.
                archiveFinishedGame(game)
            } else {
                // Decision #2: the draft on disk never trails the game by
                // more than one event. One save covers the whole snapshot.
                saveDraft()
            }
            
        case .unresolved:
            enterRecovery(game, board: board)
        }
    }
    
    /// The one door into `recovering`, shared by the unresolved-board path
    /// and the F5 commit-refused guard: flips the mode and captures the
    /// full-context desync for debugging. When wired, `recordDesync` records
    /// the last legal FEN, the physical board, the exact diff, and recent
    /// moves (Console + export buffer). When unwired, fall back to the terse
    /// Console breadcrumb so behavior never regresses headless.
    private func enterRecovery(_ game: LiveGame, board: Position) {
        mode = .recovering(game)
        // M-ux.1 (D13′): the cue rides the mode transition itself, so it
        // can never drift from what the derived flags later report. Both
        // entries route here — `.unresolved` and the F5 commit-refused
        // guard — which is exactly the "one door" the decision leans on.
        onDesync?()
        if let sessionLog {
            sessionLog.recordDesync(
                before: game.currentState,
                physical: board,
                recentSAN: game.sanMoves,
                plyCount: game.plyCount
            )
        } else {
            Self.logger.error("Board could not be reconciled — entering recovery")
        }
    }
    
    private func offerNewGameIfAtStart(_ board: Position) {
        if board == .starting {
            // A pending resume offer outranks the new-game offer: after a
            // relaunch with the pieces still set up, both would otherwise
            // present at once — and starting fresh from the dialog would
            // silently overwrite the very draft the player was being offered.
            // `deletePendingDraft()` re-runs this check so declining the
            // resume hands over to the ordinary offer on the spot.
            // A failed archive suppresses the offer too — requirements 6/8:
            // the finished game must reach the Library or be explicitly
            // discarded before a new one begins.
            if !offeredNewGameForCurrentStart && pendingDraft == nil && !archiveFailed {
                shouldOfferNewGame = true
                offeredNewGameForCurrentStart = true
                Self.logger.info("Start position detected — offering new game")
                sessionLog?.capture(.info, "Start position detected — offering new game")
            } else {
                // The suppressed settle leaves a breadcrumb: it answers the
                // real user question ("why isn't the dialog appearing?") and
                // gives tests a positive signal to await where the
                // suppression itself is a negative (F7 — the old test slept
                // a fixed 450 ms and asserted nothing had happened, which
                // passes vacuously if settle never ran at all).
                let reason = pendingDraft != nil ? "resume offer pending"
                : archiveFailed ? "unarchived finished game"
                : "already offered for this visit to the start"
                sessionLog?.capture(.debug, "Start position settled — new-game offer suppressed (\(reason))")
            }
        } else {
            offeredNewGameForCurrentStart = false
        }
    }
    
    // MARK: Game Lifecycle
    
    /// Begins a new live game with the given roster. Replaces any unfinished
    /// game (only one unfinished live game exists at a time).
    ///
    /// If the last observed physical board already matches the new game's start
    /// position — the typical path, since the new-game dialog is offered
    /// *because* the start was detected — live play starts immediately.
    /// Otherwise the session enters `awaitingSetup` and waits for the player to
    /// set up the pieces before tracking moves. Assigning `mode` here also
    /// clears any prior recovery / awaiting state structurally — there's no
    /// separate flag to remember to reset.
    internal func startNewGame(roster: LiveGame.Roster) {
        // A failed archive suppresses new-game entry structurally, not just
        // in the UI: starting fresh would overwrite the draft that is the
        // finished game's only safety net (requirements 6/8 — never lost).
        guard !archiveFailed else {
            recordError(
                "New game refused: the finished game hasn't been saved yet — retry or discard first"
            )
            return
        }
        
        // D28′: stamp the board identity at game start — the one write to
        // `Roster.board`. The dialog's roster never carries one (the forms
        // don't expose it), so this is an unconditional stamp, not a merge.
        var roster = roster
        roster.board = boardIdentity?()

        let game = LiveGame(roster: roster)
        archiveOutcome = nil
        archivedPGN = nil
        shouldOfferNewGame = false
        offeredNewGameForCurrentStart = true
        clearPlayingOverlays()
        
        let alreadySetUp = beginTracking(game)
        
        sessionLog?.record(
            .info,
            "New live game: \(roster.white) vs \(roster.black)"
            + (alreadySetUp ? "" : " — awaiting physical setup")
        )
        if !alreadySetUp {
            Self.logger.info("New game started — awaiting physical setup of starting position")
        }
        
        // Starting fresh forfeits any resume offer (the destructive
        // confirmation in the new-game sheet is the guard for that), and the
        // roster-only snapshot claims the file for the new game. A finished
        // predecessor was already archived on its finish transition (M5) —
        // its draft is gone — and a *failed* archive can't reach this line
        // (the guard above).
        pendingDraft = nil
        saveDraft()
    }
    
    /// Dismisses the new-game offer without starting one (won't re-prompt until
    /// the board leaves and returns to the start).
    internal func dismissNewGameOffer() {
        shouldOfferNewGame = false
        sessionLog?.capture(.debug, "New-game offer dismissed")
    }
    
    /// Discards the current live game and returns to idle.
    internal func discardGame() {
        mode = .idle
        clearPlayingOverlays()
        offeredNewGameForCurrentStart = false
        // The explicit-Discard exit from a failed archive (M5): the player
        // chose to lose the game, so the suppression lifts with it.
        archiveOutcome = nil
        archivedPGN = nil
        // A discarded game must not resurrect as a resume offer at the next
        // launch — Decision #3's delete path ends here, on disk too.
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
    
    /// A manual result ends any non-`playing` tracking mode: the game is
    /// decided, so neither a recovery target nor a setup target exists any
    /// longer — the board no longer owes the session a position. `playing`
    /// is where finished games live; its settle branch only watches for the
    /// start position (the "play again" signal), so the physical pieces can
    /// be cleared freely from here. Runs *between* the result landing and
    /// the archive so `needsRecovery` / `awaitingPhysicalSetup` are already
    /// false when `archiveOutcome` publishes — the HUD never shows a
    /// suppression state alongside the finished banner.
    ///
    /// The `recovering` arm is the July 2026 review's product decision. The
    /// `awaitingSetup` arm is the July 2026 sanity audit's finding: resign /
    /// agree-draw are reachable from the inspector whenever a live game
    /// isn't finished — including before the pieces are placed (fresh game)
    /// or restored (resumed draft). Left un-normalized, a finished,
    /// *archived* game stayed stranded behind the setup gate: `hudPhase`
    /// ranks `awaitingPhysicalSetup` above `isFinished`, so the HUD kept
    /// prompting for setup with no New Game button, and the mode's exit
    /// predicate (board == the dead game's current position) might never be
    /// met — for a resumed mid-game draft, a position nobody will rebuild.
    /// Rejected: reordering `hudPhase` instead — that hides the wrong mode
    /// rather than fixing it, and the settle branch would still be waiting
    /// on that unreachable position. No-op in `playing` (nothing to
    /// normalize) and `idle` (unreachable — both callers guard on a live
    /// game).
    private func normalizeModeForManualResult() {
        switch mode {
        case .idle, .playing:
            return
        case .recovering(let game):
            mode = .playing(game)
            sessionLog?.capture(.info, "Recovery ended by manual result — guidance discarded")
        case .awaitingSetup(let game):
            mode = .playing(game)
            sessionLog?.capture(.info, "Setup wait ended by manual result — nothing left to set up")
        }
        // Defensive: neither mode can have set these, but keep the exit
        // symmetrical and future-proof.
        clearPlayingOverlays()
    }
    
    // MARK: Roster
    
    /// Replaces the running game's roster wholesale (Edit Details — during
    /// play now, at the archive sheet from M5). Routed through the session
    /// rather than mutating `liveGame.roster` directly so the diagnostic
    /// timeline gets a breadcrumb and M4's draft persistence hooks a single
    /// choke point (the save below). No-op while idle. `record` (not
    /// `capture`): nothing else Console-logs a roster edit.
    internal func updateRoster(_ roster: LiveGame.Roster) {
        guard let liveGame else { return }
        liveGame.roster = roster
        sessionLog?.record(
            .info,
            "Roster updated: \(roster.white) vs \(roster.black)"
        )
        // A roster change is a draft-worthy event (Decision #2) — but once
        // the game is archived the draft is gone and edits flow through the
        // PGN door instead (the caller pairs this with the PGN write +
        // `refreshHash`); resurrecting a draft here would re-offer an
        // already-archived game at the next launch.
        if archivedPGN == nil {
            saveDraft()
        }
    }
    
    // MARK: Archive (M5)
    
    /// The archive-first choke point: called on every `isFinished`
    /// transition (auto result in `settlePlaying`, `resign`, `agreeDraw`)
    /// and from the resume self-heal. With no hook (headless unit tests,
    /// unwired builds) the draft simply stays current — it remains the
    /// safety net. Success — including a hash-deduplicated match
    /// (requirement 8) — retires the draft: the game is safe in the
    /// Library. Failure keeps the draft *and updates it* so it carries the
    /// decided result (a crash before Retry still self-heals at the next
    /// launch), and suppresses new-game entry via `archiveOutcome`.
    private func archiveFinishedGame(_ game: LiveGame) {
        // Decision #3: no `*` result ever archives. `isFinished` already
        // implies a decided result; the guard keeps it structural.
        guard game.isFinished, game.result != .ongoing else { return }
        // Already archived (a stray repeat call) — the Library row exists
        // and the draft is gone; nothing to do.
        guard archivedPGN == nil else { return }
        
        guard let onGameFinished else {
            saveDraft()
            return
        }
        
        do {
            let result = try onGameFinished(game)
            archivedPGN = result.pgn
            archiveOutcome = result.deduplicated ? .deduplicated : .archived
            // The finished game is safe in the Library — the draft's job is
            // done, and leaving it would re-offer an archived game at the
            // next launch.
            draftStore?.delete()
            // Buffer-only: PGNStore already Console-logs the archive/dedup via
            // its own os.Logger, so `capture` (not `record`) keeps the export
            // timeline complete without a second Console line — and without the
            // duplicate buffer entry a paired `record` + `capture` leaves. The
            // failure arm below uses `record`: PGNStore threw before logging,
            // so the session is the sole Console witness there.
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
                "Archive failed: \(error) — draft kept, new-game entry suppressed until Retry or Discard"
            )
        }
    }
    
    /// Re-attempts a failed archive (the HUD's Retry). No-op unless the
    /// last attempt failed and the finished game is still on screen.
    internal func retryArchive() {
        guard case .failed = archiveOutcome,
              let game = liveGame, game.isFinished else { return }
        sessionLog?.record(.info, "Retrying archive…")
        archiveFinishedGame(game)
    }
    
    /// Dismisses the archive confirmation (the player closed the sheet).
    /// Clears a *success* outcome only — a failure is cleared exclusively
    /// by a successful retry or an explicit discard, never by evasion.
    /// `archivedPGN` survives so post-archive detail edits keep flowing
    /// through the Library row until the next game replaces it.
    internal func acknowledgeArchive() {
        switch archiveOutcome {
        case .archived, .deduplicated:
            archiveOutcome = nil
        case .failed, nil:
            break
        }
    }
    
    // MARK: Draft Persistence (M4)
    
    /// Loads any draft left behind by a previous run into `pendingDraft`.
    /// Called once from `App.init()` right after `draftStore` is wired;
    /// with no store, or no file (the common launch), it's a no-op. A file
    /// that exists but can't be loaded surfaces as `.corrupt` rather than
    /// being deleted or ignored: the player decides, and until they do the
    /// file remains on disk as inspectable diagnostics.
    internal func loadPendingDraft() {
        guard let draftStore else { return }
        do {
            guard let draft = try draftStore.load() else { return }
            pendingDraft = .resumable(draft)
            sessionLog?.record(
                .info,
                "Draft found: \(draft.white) vs \(draft.black) "
                + "(\(draft.sanMoves.count) plies) — offering resume"
            )
        } catch {
            pendingDraft = .corrupt
            recordError("Draft file can't be read: \(error) — offering delete")
        }
    }
    
    /// Rebuilds the pending draft into the running game (M4.3), replaying
    /// its SAN transcript through the chess core via `LiveGame(resuming:)`.
    /// On success the session enters the same gate as a fresh game:
    /// `awaitingSetup` until the physical pieces match the game's *current*
    /// position — the existing exit predicate already compares against the
    /// current state, so "restore the board to where the game left off"
    /// needs no new mode. A draft that loaded but won't replay flips to
    /// `.corrupt` (delete becomes the only offer).
    internal func resumePendingDraft() {
        guard case .resumable(let draft) = pendingDraft else { return }
        do {
            let game = try LiveGame(resuming: draft)
            pendingDraft = nil
            shouldOfferNewGame = false
            offeredNewGameForCurrentStart = true
            clearPlayingOverlays()
            
            if game.isFinished {
                // The self-heal (M5): a decided draft means a previous run
                // stopped between the finish and a successful Library save
                // (crash, or a failed archive). No setup gate — nothing is
                // left to track — and archive-first applies here exactly as
                // on a live finish. Deduplication makes a double-heal
                // harmless.
                mode = .playing(game)
                sessionLog?.record(
                    .info,
                    "Resumed a finished game (\(draft.result.rawValue)) — archiving now"
                )
                archiveFinishedGame(game)
            } else {
                let alreadySetUp = beginTracking(game)
                
                sessionLog?.record(
                    .info,
                    "Resumed live game: \(draft.white) vs \(draft.black) (\(game.plyCount) plies)"
                    + (alreadySetUp ? "" : " — awaiting physical setup")
                )
            }
        } catch {
            pendingDraft = .corrupt
            recordError("Draft failed to resume: \(error) — offering delete")
        }
    }
    
    /// Deletes the pending draft — the player declined the resume, or the
    /// draft is corrupt. Clears the offer, removes the file, and — if the
    /// board happens to be sitting at the start position — lets the ordinary
    /// new-game offer take over on the spot rather than waiting for the
    /// pieces to leave the start and return.
    internal func deletePendingDraft() {
        guard pendingDraft != nil else { return }
        pendingDraft = nil
        draftStore?.delete()
        sessionLog?.record(.info, "Pending draft deleted")
        if case .idle = mode, let board = lastObservedBoard {
            offerNewGameIfAtStart(board)
        }
    }
    
    /// Writes the running game's snapshot (M4.2). Called after every
    /// committed ply, every manual result, every roster edit, and at game
    /// start, so the file on disk never trails the game by more than one
    /// event. Failures are logged loudly but don't interrupt play — losing
    /// one snapshot beats halting a live game, and the very next event
    /// retries the write.
    private func saveDraft() {
        guard let game = liveGame, let draftStore else { return }
        do {
            try draftStore.save(game.draftSnapshot)
        } catch {
            recordError("Draft save failed: \(error)")
        }
    }
    
    // MARK: Private — Ghost
    
    /// Sets both ghost fields together for a castle in progress: the piece
    /// still in the player's hand, ghosted on its destination. King-first
    /// castling awaits the rook; the two-handed variant whose rook hand lands
    /// first awaits the king. The settled physical board is what tells them
    /// apart — the rook already sitting on its destination means the king is
    /// the airborne piece.
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
    
    /// Clears both ghost fields together — they're always set and cleared as a
    /// pair (non-nil iff a castle is mid-flight).
    private func clearGhost() {
        castlingGhostSquare = nil
        castlingGhostPiece = nil
    }
    
    /// The transient playing-overlays as one unit. `settlePlaying` recomputes
    /// them every settle and the four lifecycle exits drop them; naming the set
    /// means a future third overlay is added in one place rather than five.
    /// The recovery-exit in `settle` deliberately keeps the narrower
    /// `clearGhost()`: a correction hint can't survive into recovery.
    private func clearPlayingOverlays() {
        clearGhost()
        correctionHint = nil
    }
    
    /// Enters tracking for `game`: straight to `playing` when the pieces
    /// already stand where the game expects them, otherwise through the setup
    /// gate. Returns whether the gate was skipped, which both callers put in
    /// their log line. A fresh game and a resumed draft ask the identical
    /// question of the identical `lastObservedBoard` — one home for it.
    @discardableResult
    private func beginTracking(_ game: LiveGame) -> Bool {
        let alreadySetUp = lastObservedBoard == game.currentState.position
        mode = alreadySetUp ? .playing(game) : .awaitingSetup(game)
        return alreadySetUp
    }
    
    /// An error that must reach *somewhere*: the exportable timeline when
    /// wired, Console when not. `record` already Console-mirrors, so the
    /// fallback fires only headless — which four call sites each open-coded,
    /// every one of them having to remember the `nil` check and keep two
    /// copies of the message in step.
    private func recordError(_ message: String) {
        if let sessionLog {
            sessionLog.record(.error, message)
        } else {
            Self.logger.error("\(message, privacy: .public)")
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
