//
//  DGTLiveSession.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 26/05/2026.
//

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
/// The 300 ms quiescence window is the one piece of timing the pure engine
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
/// should prompt for setup rather than show recovery).
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
    
    /// Set when the standard start position is detected with no *unfinished*
    /// game running — while idle, or while a finished game is still on screen —
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
    
    // MARK: Diagnostics
    
    /// Optional exportable diagnostic timeline. Wired by the app
    /// (`session.sessionLog = log`); when nil, the session falls back to its
    /// own Console logger and nothing else changes.
    @ObservationIgnored internal var sessionLog: DGTSessionLog?
    
    // MARK: Private State
    
    @ObservationIgnored private var quiescenceTask: Task<Void, Never>?
    @ObservationIgnored private var quiescence: Duration = .milliseconds(300)
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
                // A decided game stays on screen until it's replaced,
                // discarded, or (D7, M5) archived — but it must never settle
                // through reconstruction again. Post-result board changes are
                // *expected* (players shake hands, clear pieces, reset), so
                // treating them as desyncs would trip bogus recovery the
                // moment M3 makes recovery visible. Instead, behave like
                // idle's offer logic: watch only for the standard start, and
                // when the pieces are reset, offer a fresh game. This is what
                // closes the finish → reset → offer loop end-to-end.
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
        clearGhost()
        correctionHint = nil
        
        switch DGTReconstructor.reconstruct(from: game.currentState, physical: board) {
        case .noChange:
            sessionLog?.capture(.debug, "settle: no change")
            
        case .inProgress:
            sessionLog?.capture(.debug, "settle: move in progress (pieces lifted, none placed)")
            
        case .castlingInProgress(let castling):
            // King has moved two squares; await the rook, showing a ghost.
            setGhost(for: castling)
            sessionLog?.capture(
                .info,
                "settle: castling in progress — ghost rook awaited at \(castling.rookTo.map(\.algebraicNotation) ?? "?")"
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
            game.commit(move)
            sessionLog?.capture(
                .info,
                "settle: committed \(game.sanMoves.last ?? "?") [ply \(game.plyCount)]"
            )
            if game.isFinished {
                Self.logger.info("Live game finished: \(game.result.rawValue, privacy: .public)")
                sessionLog?.capture(.info, "Live game finished: \(game.result.rawValue)")
            }
            
        case .unresolved:
            mode = .recovering(game)
            // Full-context capture for debugging. When wired, this records the
            // last legal FEN, the physical board, the exact diff, and recent
            // moves (Console + export buffer). When unwired, fall back to the
            // terse Console breadcrumb so behavior never regresses.
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
    }
    
    private func offerNewGameIfAtStart(_ board: Position) {
        if board == .starting {
            if !offeredNewGameForCurrentStart {
                shouldOfferNewGame = true
                offeredNewGameForCurrentStart = true
                Self.logger.info("Start position detected — offering new game")
                sessionLog?.capture(.info, "Start position detected — offering new game")
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
        let game = LiveGame(roster: roster)
        shouldOfferNewGame = false
        offeredNewGameForCurrentStart = true
        clearGhost()
        correctionHint = nil
        
        let alreadySetUp = lastObservedBoard == game.currentState.position
        mode = alreadySetUp ? .playing(game) : .awaitingSetup(game)
        
        sessionLog?.record(
            .info,
            "New live game: \(roster.white) vs \(roster.black)"
            + (alreadySetUp ? "" : " — awaiting physical setup")
        )
        if !alreadySetUp {
            Self.logger.info("New game started — awaiting physical setup of starting position")
        }
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
        clearGhost()
        correctionHint = nil
        offeredNewGameForCurrentStart = false
        sessionLog?.capture(.info, "Live game discarded")
    }
    
    // MARK: Manual Result Passthrough
    
    internal func resign(_ color: PieceColor) {
        liveGame?.resign(color)
        sessionLog?.capture(.info, "Manual result: \(color) resigned")
    }
    
    internal func agreeDraw() {
        liveGame?.agreeDraw()
        sessionLog?.capture(.info, "Manual result: draw agreed")
    }
    
    // MARK: Roster Passthrough
    
    /// Applies edited roster metadata to the running game (M3.3's "Edit
    /// Details" sheet). Views route roster edits through the session rather
    /// than mutating `liveGame.roster` directly so there is a single choke
    /// point that knows the game changed — M4 hooks draft persistence here.
    /// No-op when no game is running.
    internal func updateRoster(_ roster: LiveGame.Roster) {
        guard let game = liveGame else { return }
        game.roster = roster
        sessionLog?.capture(.info, "Roster updated: \(roster.white) vs \(roster.black)")
    }
    
    // MARK: Private — Ghost
    
    /// Sets both ghost fields together for a castle in progress — the rook's
    /// destination and a rook of the moving side.
    private func setGhost(for castling: Move) {
        castlingGhostSquare = castling.rookTo
        castlingGhostPiece = Piece(castling.pieceColor, .rook)
    }
    
    /// Clears both ghost fields together — they're always set and cleared as a
    /// pair (non-nil iff a castle is mid-flight).
    private func clearGhost() {
        castlingGhostSquare = nil
        castlingGhostPiece = nil
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
