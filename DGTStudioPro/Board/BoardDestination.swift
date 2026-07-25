//
//  BoardDestination.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import os
import SwiftData
import SwiftUI

/// Board destination. When `loadedGameID` is non-nil, looks up the PGN,
/// builds a `Game`, and renders the board + inspector. When nil, it still
/// shows a board — the live DGT mirror (`connection.physicalBoard`, empty
/// until a board is connected), which is the M1 raw-mirror surface. There
/// is no landing/error card; the board is always on screen.
///
/// The live branch is the M3 live-play surface: the live game's
/// last-move/check highlights overlaid on the mirrored physical position,
/// the new-game dialog (auto-offered on start-position detection, or
/// requested from the sidebar's session panel — all status messaging
/// re-homed there by D15′; the stage above the board stays clear), and
/// the live inspector
/// (`LiveGameInspectorView`). From M4 it also presents the crash-safety
/// resume offer: when the session finds a draft at launch
/// (`session.pendingDraft`), an alert forks between Resume and Delete —
/// Decision #3's only two options — with a delete-only variant for a
/// corrupt draft file. It also overlays a 50%-opacity ghost rook on
/// `session.castlingGhostSquare` during a mid-castle (king moved, rook not
/// yet). The PGN-replay branch deliberately has none of this — live
/// surfaces are about the *physical* board vs the live game's state, which
/// is orthogonal to scrubbing a finished PGN.
///
/// `loadedGameID` is bound to the enclosing tab's `WindowGroup` value,
/// so each native tab has its own game (or none). Switching to Library
/// in the sidebar doesn't clear the loaded game — it stays "loaded" in
/// the tab and reappears when the user returns to Board.
///
/// Per-tab state (resolved PGN/Game, perspective, inspector visibility)
/// lives on the enclosing `ContentView`'s `TabState`, NOT on this view.
/// This destination is recreated by SwiftUI every time the sidebar
/// switches to and from `.board`; storing live state on `@State` here
/// would lose scrub position, perspective, and inspector toggle on every
/// destination round-trip.
internal struct BoardDestination: View {
    
    // MARK: Static Constants
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "boardload"
    )
    
    // MARK: Bound State
    
    @Binding internal var loadedGameID: PersistentIdentifier?
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    
    @Bindable internal var tabState: TabState
    
    // MARK: Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(DGTConnection.self) private var connection
    @Environment(DGTLiveSession.self) private var session
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    
    // MARK: View State
    
    /// True after "Keep for Now" on the corrupt-draft alert, so it doesn't
    /// re-present every render for the rest of this visit. The file stays on
    /// disk as diagnostics; the offer returns at the next launch (or the
    /// next visit to Board). Transient by design, like the flag above.
    @State private var corruptOfferDeferred = false
    
    /// True for a beat after recovery auto-resolves, flashing "Position
    /// restored — play continues." under the HUD (M6.2). Transient by
    /// design, like the flags above.
    @State private var showsRestoredFlash = false
    
    /// True while the movetext editor sheet is open (M-lib.3). Transient by
    /// design, like the flags above — losing "sheet open" across a sidebar
    /// round-trip is fine.
    @State private var editingMovetext = false
    
    // MARK: Body
    
    internal var body: some View {
        Group {
            if let pgn = tabState.boardPGN, let game = tabState.boardGame {
                content(pgn: pgn, game: game)
            } else {
                // No game loaded → the live-play surface: always a board
                // (mirroring the physical DGT board, empty until one is
                // connected — the M1 raw mirror), plus the M3 HUD, live
                // overlays, new-game dialog, and live inspector.
                liveSurface
            }
        }
        // M8.2's load-error surface lives in the sidebar session panel
        // since D15′ (behavior unchanged, surface moved — `ContentView`
        // renders `tabState.boardLoadError` there).
        .navigationTitle(tabState.boardPGN?.name ?? "Board")
        .toolbar {
            ToolbarItem {
                Button {
                    tabState.boardPerspective = tabState.boardPerspective.opponent
                } label: {
                    Label("Flip Board", systemImage: "arrow.up.arrow.down")
                }
                // Enabled even with no game so it serves as the manual
                // orientation toggle for the live mirror (view-only flip,
                // separate from the decoder's coordinate transform).
                .accessibilityIdentifier(AccessibilityID.boardFlipButton)
            }
            
            ToolbarItem {
                Button {
                    editingMovetext = true
                } label: {
                    Label("Edit Moves…", systemImage: "square.and.pencil")
                }
                // Only a loaded archived game has movetext to edit; disabled on
                // the live mirror (no `boardPGN`).
                .disabled(tabState.boardPGN == nil)
                .accessibilityIdentifier(AccessibilityID.boardEditMovesButton)
            }
        }
        .inspectorToggle(
            isPresented: $tabState.boardInspectorPresented,
            identifier: AccessibilityID.boardInspectorToggle
        )
        .dgtConnectionToolbar()
        // The new-game dialog, at body level since D15′: the sidebar's
        // New Game button reaches Board with a game loaded too, so the
        // sheet can no longer live on the live branch alone. The *auto*
        // offer stays gated to the live branch inside the binding — a tab
        // reviewing a PGN isn't interrupted, exactly as before.
        // Presentation-race disposition (M11.4): this sheet, the movetext
        // editor and archive sheets below, the sidebar's SmartTag editor at
        // the ContentView root, and the connect dialog from the toolbar all
        // share the window's single modal slot. When one wants to present
        // while another is up (a game finishes → this offer, while the connect
        // dialog or tag editor is open), SwiftUI queues it and presents on the
        // open sheet's dismissal. That dismiss-then-present order is the
        // intended UX — finish the connection/edit, then answer the offer — so
        // it's documented as deliberate rather than restructured into one
        // enum-driven sheet (which would couple three independent concerns
        // through a single presentation state).
        .sheet(isPresented: isNewGameSheetPresented) {
            NewLiveGameSheet(
                onStart: { roster in
                    session.startNewGame(roster: roster)
                    tabState.manualNewGameRequested = false
                },
                onNotNow: { isNewGameSheetPresented.wrappedValue = false },
                // A resumable draft counts as an unfinished game too:
                // starting fresh overwrites its file, so it gets the same
                // destructive confirmation (a *corrupt* file is not a
                // game — overwriting it needs no ceremony).
                replacesUnfinishedGame: session.liveGame?.isFinished == false
                || session.resumableDraft != nil
            )
        }
        // M-lib.3 (D18′) — the movetext editor, at body level and guarded by a
        // loaded PGN (the toolbar affordance is disabled without one). It's
        // mutually exclusive with the live new-game/archive sheets by branch
        // (those present only when `boardPGN == nil`), so it joins that chain
        // without contending. Commit runs the store write and rebuilds the
        // cached Game, whose scrub state describes the pre-edit moves.
        .sheet(isPresented: $editingMovetext) {
            if let pgn = tabState.boardPGN {
                MovetextEditorSheet(pgn: pgn) { proposed in
                    applyEditedMovetext(proposed, to: pgn)
                }
            }
        }
        // Phase 11: publish the active game so GameNavigationCommands' arrow
        // keys can scrub it.
        .focusedSceneValue(\.activeGame, tabState.boardGame)
        .onAppear { loadIfNeeded() }
        .onChange(of: loadedGameID) { _, _ in loadIfNeeded() }
    }
    
    // MARK: Board Surface
    
    /// The board itself, shared by the game view and the live mirror. Both
    /// render the same `BoardView` with the same padding, sizing, and
    /// `"board"` accessibility identifier — only the inputs differ. Keeping
    /// this in one place means the identifier and the modifier tail can't
    /// drift between the two branches.
    private func boardSurface(
        position: Position,
        tracker: PieceTracker,
        lastMove: LastMove?,
        checkSquare: Square?,
        ghostSquare: Square?,
        ghostPiece: Piece?,
        attentionSquares: Set<Square> = [],
        targetSquares: Set<Square> = []
    ) -> some View {
        BoardView(
            position:         position,
            pieceTracker:     tracker,
            style:            boardStyle,
            perspective:      tabState.boardPerspective,
            lastMove:         lastMove,
            checkSquare:      checkSquare,
            selectedSquare:   nil,
            ghostSquare:      ghostSquare,
            ghostPiece:       ghostPiece,
            attentionSquares: attentionSquares,
            targetSquares:    targetSquares
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.board)
    }
    
    // MARK: Content
    
    private func content(pgn: PGN, game: Game) -> some View {
        // PGN-replay path: no ghost. Ghosts only make sense against the
        // live physical board.
        boardSurface(
            position:    game.currentState.position,
            tracker:     game.currentTracker,
            lastMove:    game.lastMove,
            checkSquare: game.checkSquare,
            ghostSquare: nil,
            ghostPiece:  nil
        )
        .inspector(isPresented: $tabState.boardInspectorPresented) {
            BoardInspectorView(
                pgn: pgn,
                evaluations: pgn.evaluations.map {
                    $0?.whiteWinProbability ?? 0.5
                },
                moves: pgn.moves,
                currentMoveIndex: game.currentPly > 0 ? game.currentPly - 1 : nil,
                style: boardStyle,
                onMoveTapped: { index in game.jump(to: index + 1)
                }
            )
            .inspectorColumnWidth(min: 325, ideal: 320, max: 430)
        }
    }
    
    // MARK: Live Surface
    
    /// The live-play surface (M3, slimmed by D15′): the mirror board and
    /// the live inspector, plus the resume/corrupt-draft forks and the
    /// archive confirmation. All status messaging — the status card, the
    /// recovery checklist, the restored flash — lives in the sidebar's
    /// `SessionSidebarPanel`; the stage above the board is clear by
    /// invariant. The recovery *overlays* below are the board's and stay.
    private var liveSurface: some View {
        mirrorBoard
            .inspector(isPresented: $tabState.boardInspectorPresented) {
                liveInspector
                    .inspectorColumnWidth(min: 325, ideal: 320, max: 430)
            }
        // M4.3 — the resume offer. A modal fork, not a HUD banner,
        // because Decision #3 makes this a genuine either/or the player
        // should answer before anything else touches the draft.
            .alert(
                "Resume unfinished game?",
                isPresented: isResumeOfferPresented,
                presenting: session.resumableDraft
            ) { _ in
                Button("Resume") { session.resumePendingDraft() }
                Button("Delete", role: .destructive) { session.deletePendingDraft() }
            } message: { draft in
                Text(resumeOfferMessage(for: draft))
            }
        // The corrupt-draft variant: resume isn't on the table, and
        // "Keep for Now" leaves the file on disk as diagnostics.
            .alert(
                "Saved game can't be read",
                isPresented: isCorruptDraftOfferPresented
            ) {
                Button("Delete", role: .destructive) { session.deletePendingDraft() }
                Button("Keep for Now", role: .cancel) { corruptOfferDeferred = true }
            } message: {
                Text(
                    "A game saved by a previous session couldn't be loaded. "
                    + "Deleting it can't be undone; keeping it leaves the file "
                    + "in place in case it's needed for diagnostics."
                )
            }
        // M5 — the archive confirmation. Auto-presents when a finished game
        // lands in the Library (fresh or deduplicated); dismissal
        // acknowledges the outcome so it won't re-present, while the
        // archived row stays editable from the inspector.
            .sheet(isPresented: isArchiveConfirmationPresented) {
                if let pgn = session.archivedPGN {
                    EditGameInfoSheet(
                        pgn: pgn,
                        deduplicated: session.archiveOutcome == .deduplicated,
                        onSave: { roster in
                            applyEditedInfo(roster, to: pgn)
                            session.updateRoster(roster)
                        }
                    )
                }
            }
    }
    
    /// Presents the new-game sheet whenever the session offers one
    /// (`shouldOfferNewGame`) or the HUD requested one manually. Dismissal
    /// through the binding (swipe, ⎋, Not Now) counts as "Not Now" — it
    /// clears the manual request and tells the session not to re-prompt
    /// until the board leaves and returns to the start.
    /// Presents the resume alert while a resumable draft pends. The setter
    /// deliberately ignores dismissal: the offer is answered by its buttons
    /// (which clear `pendingDraft`, flipping the getter), never by evasion —
    /// Decision #3 is a fork, not a suggestion.
    private var isResumeOfferPresented: Binding<Bool> {
        Binding(
            get: { session.resumableDraft != nil },
            set: { _ in }
        )
    }
    
    /// Presents the corrupt-draft alert until answered or deferred for this
    /// visit ("Keep for Now" sets `corruptOfferDeferred`).
    private var isCorruptDraftOfferPresented: Binding<Bool> {
        Binding(
            get: { session.pendingDraftIsCorrupt && !corruptOfferDeferred },
            set: { _ in }
        )
    }
    
    /// The resume alert's body: who was playing, how far they got, when the
    /// draft was last written — and a heads-up when the draft is already
    /// decided (finished but not yet archived; resuming triggers the M5
    /// self-heal archive).
    private func resumeOfferMessage(for draft: LiveGameDraft) -> String {
        let plies = draft.sanMoves.count
        // The alert is a display surface like any other (D23′) — the draft
        // stores tag form, so it renders through the transform.
        let pairing = "\(PlayerName.displayForm(of: draft.white)) vs \(PlayerName.displayForm(of: draft.black))"
        var lines = [
            "\(pairing) — \(plies) \(plies == 1 ? "move" : "moves").",
            "Last saved \(draft.updatedAt.formatted(date: .abbreviated, time: .shortened))."
        ]
        if draft.result != .ongoing {
            lines.append(
                "This game already finished (\(draft.result.rawValue)) "
                + "but hasn't been saved to the Library yet."
            )
        }
        return lines.joined(separator: "\n")
    }
    
    /// Presents the archive confirmation while a *successful* outcome is
    /// unacknowledged. Dismissal (Done, ⎋, swipe) acknowledges it; a
    /// failure never presents this sheet — it lives on the HUD as
    /// Retry-or-discard.
    private var isArchiveConfirmationPresented: Binding<Bool> {
        Binding(
            get: {
                session.archiveOutcome == .archived
                || session.archiveOutcome == .deduplicated
            },
            set: { presented in
                guard !presented else { return }
                session.acknowledgeArchive()
            }
        )
    }
    
    /// Applies edited details to the archived Library row through
    /// `PGNStore.applyEdit(to:_:)`, which owns the one-hash/two-doors
    /// rehash structurally (M11 review) — this door no longer has to
    /// remember two steps. Also renames the row when it still carried the
    /// default "White vs Black" name, so the title tracks the players.
    private func applyEditedInfo(_ roster: LiveGame.Roster, to pgn: PGN) {
        do {
            try PGNStore(modelContext: modelContext).applyEdit(to: pgn) { pgn in
                let hadDefaultName = pgn.name == pgn.defaultDisplayName
                
                pgn.event = roster.event
                pgn.site  = roster.site
                pgn.date  = roster.date
                pgn.round = roster.round
                pgn.white = roster.white
                pgn.black = roster.black
                if hadDefaultName { pgn.name = pgn.defaultDisplayName }
            }
        } catch {
            Self.logger.error(
                "archive edit failed to persist: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    /// Commits an edited movetext through `PGNStore.applyMovetextEdit`
    /// (validation + canonical store + hash refresh + eval invalidation, one
    /// transaction) and rebuilds the on-board `Game`: the moves changed
    /// underfoot, so the cached game and its scrub position now describe the
    /// old movetext, and `loadIfNeeded`'s cache guard would otherwise skip the
    /// reload. A rejection at commit would mean the sheet enabled Save on an
    /// invalid game — it can't (same pure validation both sides) — so only a
    /// persistence failure is logged.
    private func applyEditedMovetext(_ proposed: [String], to pgn: PGN) {
        do {
            let outcome = try PGNStore(modelContext: modelContext)
                .applyMovetextEdit(to: pgn, proposed: proposed)
            if case .success = outcome {
                tabState.boardGame = nil
                loadIfNeeded()
            } else {
                Self.logger.error("movetext edit unexpectedly rejected at commit")
            }
        } catch {
            Self.logger.error(
                "movetext edit failed to persist: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    private var isNewGameSheetPresented: Binding<Bool> {
        Binding(
            get: {
                // The auto-offer presents only on the live branch — a tab
                // reviewing a PGN isn't interrupted (pre-D15′ behavior,
                // now explicit instead of structural). The manual request,
                // reachable from the sidebar on any branch, presents
                // everywhere.
                tabState.manualNewGameRequested
                || (session.shouldOfferNewGame && tabState.boardPGN == nil)
            },
            set: { presented in
                guard !presented else { return }
                tabState.manualNewGameRequested = false
                if session.shouldOfferNewGame {
                    session.dismissNewGameOffer()
                }
            }
        )
    }
    
    /// Inspector content for the live branch: the live game's details and
    /// controls when one exists, otherwise a hint (so the inspector toggle
    /// is never a dead switch on the mirror) — connection-aware, since the
    /// disconnected message lives here now rather than above the board.
    @ViewBuilder
    private var liveInspector: some View {
        if let game = session.liveGame {
            LiveGameInspectorView(
                game: game,
                onUpdateRoster: { roster in
                    session.updateRoster(roster)
                    // Post-archive, Edit Details keeps the Library row in
                    // step too (the one-hash discipline lives in the helper).
                    if let pgn = session.archivedPGN {
                        applyEditedInfo(roster, to: pgn)
                    }
                },
                onResign: { session.resign($0) },
                onAgreeDraw: { session.agreeDraw() },
                onDiscard: { session.discardGame() }
            )
        } else if connection.isConnected {
            ContentUnavailableView(
                "No Live Game",
                systemImage: "checkerboard.rectangle",
                description: Text(
                    "Start a game from the board to see its details and moves here."
                )
            )
        } else {
            // The former HUD `disconnected` banner, relocated: this empty
            // state used to say "start a game from the board" — impossible
            // advice with no board — while the banner spent the strip
            // above the board on a message with no action.
            ContentUnavailableView(
                "No Board Connected",
                systemImage: "cable.connector.horizontal",
                description: Text(
                    "Connect your DGT board to record games live."
                )
            )
        }
    }
    
    // MARK: Live Mirror
    
    /// The board shown whenever no game is loaded. The *position* always
    /// renders the DGT connection's live `physicalBoard` (empty when nothing
    /// is connected) with an empty `PieceTracker` — mid-move, the physical
    /// and legal positions diverge, so identity-keyed animation against the
    /// physical board could mis-key (tracker parity stays a v1.x item). Only
    /// the *overlays* come from the live game (M3.2): last-move and check
    /// highlights, plus the mid-castle ghost rook from the session. The
    /// check highlight keys off the legal game state, so mid-move it can sit
    /// on a square the king has physically just left — same accepted
    /// tradeoff, resolved at the next settle.
    private var mirrorBoard: some View {
        boardSurface(
            position:         connection.physicalBoard,
            tracker:          .empty,
            lastMove:         session.liveGame?.lastMove,
            checkSquare:      session.liveGame?.checkSquare,
            ghostSquare:      session.castlingGhostSquare,
            ghostPiece:       session.castlingGhostPiece,
            attentionSquares: recoveryGuidance?.attentionSquares ?? [],
            targetSquares:    recoveryGuidance?.targetSquares ?? []
        )
    }
    
    /// The live restore checklist while `recovering` (M6.2), nil otherwise.
    /// Recomputed on every observable change of `connection.physicalBoard`,
    /// so highlights and the instruction list shrink as squares are fixed —
    /// a 64-square diff per render is cheap (reach for `.task(id:)`
    /// memoization only if profiling ever demands it).
    private var recoveryGuidance: RecoveryGuidance? {
        guard session.needsRecovery, let game = session.liveGame else { return nil }
        return RecoveryGuidance(
            physical: connection.physicalBoard,
            target: game.currentState.position
        )
    }
    
    // MARK: Loading
    
    /// Resolves the bound `loadedGameID` to a concrete PGN + Game and
    /// caches the result on `tabState`. No-op when the cached PGN
    /// already matches the ID — important because this is called from
    /// both `onAppear` (every time the Board destination re-enters the
    /// view tree on a sidebar switch) and `onChange(of: loadedGameID)`,
    /// and we don't want to rebuild the `Game` (and lose scrub position)
    /// when the ID hasn't actually changed.
    private func loadIfNeeded() {
        guard let id = loadedGameID else {
            Self.logger.debug("loadIfNeeded: loadedGameID is nil — clearing")
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = nil
            return
        }
        
        if tabState.boardPGN?.persistentModelID == id, tabState.boardGame != nil {
            Self.logger.debug(
                "loadIfNeeded: cache hit for '\(self.tabState.boardPGN?.name ?? "?", privacy: .public)' — no reload"
            )
            return
        }
        
        Self.logger.debug("loadIfNeeded: resolving id \(String(describing: id), privacy: .public)")
        
        guard let loadedPGN = modelContext.model(for: id) as? PGN else {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = "The game could not be found in the library."
            Self.logger.error(
                "PGN lookup failed for id \(String(describing: id), privacy: .public)"
            )
            return
        }
        
        do {
            let newGame = try Game(pgn: loadedPGN)
            tabState.boardPGN = loadedPGN
            tabState.boardGame = newGame
            tabState.boardLoadError = nil
            Self.logger.info(
                "Opened game: \(loadedPGN.name, privacy: .public) [\(loadedPGN.moves.count) plies]"
            )
        } catch let error as Game.BuildError {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            if case .invalidMove(let index, let san, let underlying) = error {
                tabState.boardLoadError = "Move \(index + 1) couldn't be parsed."
                Self.logger.error(
                    """
                    Game.init failed for \(loadedPGN.name, privacy: .public): \
                    move \(index + 1) (index \(index)) SAN '\(san, privacy: .public)' \
                    failed with \(String(describing: underlying), privacy: .public). \
                    Prior moves: [\(loadedPGN.moves.prefix(index).joined(separator: " "), privacy: .public)]
                    """
                )
            } else {
                tabState.boardLoadError = "The game's move list couldn't be parsed."
                Self.logger.error(
                    "Game.init failed for \(loadedPGN.name, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        } catch {
            tabState.boardPGN = nil
            tabState.boardGame = nil
            tabState.boardLoadError = "Couldn't open the game: \(error.localizedDescription)"
            Self.logger.error(
                "Game.init failed unexpectedly for \(loadedPGN.name, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
