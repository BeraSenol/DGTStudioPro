import os
import SwiftData
import SwiftUI

/// Board destination. Non-nil `loadedGameID`: PGN lookup → `Game` → board + inspector. Nil: the
/// live DGT mirror (`connection.physicalBoard`, empty until connected) - the board is always on
/// screen. Per-tab state lives on `ContentView`'s `TabState`, not here; switching destinations
/// does not clear a tab's game.
struct BoardDestination: View {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.boardload)
    
    // MARK: Bound State
    
    @Binding var loadedGameID: PersistentIdentifier?
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    
    @Bindable var tabState: TabState
    
    // MARK: Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(DGTConnection.self) private var connection
    @Environment(DGTLiveSession.self) private var session
    @Environment(BoardSounds.self) private var boardSounds
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    
    // MARK: View State
    
    /// "Keep for Now" deferral for the corrupt-draft alert, this visit only. Transient by design -
    /// losing it across a sidebar round-trip re-offers, which is the safe direction.
    @State private var corruptOfferDeferred = false
    
    // (An orphaned doc block for `activeEditor` stood here until 16 Aug 2026 - the property left
    // when Get Info absorbed the game editors, its doc did not. A doc comment with no declaration under it is debris, not record;
    // the epitaph lives in the decision log.)

    /// The connect dialog, lifted out of the toolbar modifier - always one of the sheets contending
    /// for the window's single modal slot.
    @State private var showConnectSheet = false
    
    /// Set by the Game menu's ⌘I (a `Commands` scene cannot open windows); cleared as soon as this
    /// view has. A trigger, not a stored request - the subject is derivable here (`getInfoSubject`).
    @State private var getInfoRequested = false

    /// Registry for the archive sheet's seat pickers. Queried *here*: `EditGameInfoSheet` is
    /// container-free so its previews build - a `@Query` inside it would trap the canvas.
    @Query(sort: \Player.name) private var knownPlayers: [Player]

    // MARK: Body
    
    var body: some View {
        Group {
            if let pgn = tabState.boardPGN, let game = tabState.boardGame {
                content(pgn: pgn, game: game)
            } else {
                // No game loaded → the live surface: the mirror board, HUD, live overlays, dialogs.
                liveSurface
            }
        }
        // Load-error surface lives in the sidebar session panel.
        .navigationTitle(tabState.boardPGN?.name ?? "Board")
        // Subtitle is *state*; title is identity; the inspector's `GameHeadline` is the pairing.
        // A tab reviewing a PGN has no business announcing a desync it isn't party to.
        .navigationSubtitle(
            DestinationSubtitle.board(
                phase: .current(session: session, connection: connection),
                reviewing: tabState.boardPGN == nil
                    ? nil
                    : tabState.boardGame?.currentState.activeColor
            ) ?? ""
        )
        .toolbar { boardToolbarContent }
        .sheet(isPresented: $showConnectSheet) {
            DGTConnectionView()
        }
        // The new-game dialog at body level: the sidebar's New Game button reaches Board with a
        // game loaded too. The *auto* offer stays gated to the live branch inside the binding - a tab
        // reviewing a PGN isn't interrupted.
        .sheet(isPresented: isNewGameSheetPresented) {
            NewLiveGameSheet(
                onStart: { roster in
                    session.startNewGame(roster: roster)
                    tabState.manualNewGameRequested = false
                },
                onNotNow: { isNewGameSheetPresented.wrappedValue = false },
                // A resumable draft counts as unfinished: starting fresh overwrites its file, so same
                // destructive confirmation (a *corrupt* file is not a game).
                replacesUnfinishedGame: session.liveGame?.isFinished == false
                || session.resumableDraft != nil
            )
        }
        // The removed the last editing surface here: an archived game's roster is edited in Get Info.
        .focusedSceneValue(\.activeGame, tabState.boardGame)
        // Get Info trigger published only when this tab has a subject, so the menu item's `disabled(_:)`
        // reads a condition producible both ways.
        .focusedSceneValue(
            \.boardGetInfoRequest,
            getInfoSubject == nil ? nil : $getInfoRequested
        )
        // Cleared before opening, so a second ⌘I is a fresh request, not a no-op against a stale flag.
        .onChange(of: getInfoRequested) { _, requested in
            guard requested else { return }
            getInfoRequested = false
            if let subject = getInfoSubject { openWindow(value: subject) }
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: loadedGameID) { _, _ in loadIfNeeded() }
    }
    
    // MARK: Toolbar
    
    /// One stream, in written order: items merged from separate `.toolbar` modifiers arrive without
    /// a region boundary - undivided toolbar, inspector column tucked beneath it.
    @ToolbarContentBuilder
    private var boardToolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                tabState.boardPerspective = tabState.boardPerspective.opponent
            } label: {
                Label("Flip Board", systemImage: "arrow.up.arrow.down")
            }
            // Enabled with no game: the manual orientation toggle for the live mirror (view-only flip).
            .accessibilityIdentifier(AccessibilityID.boardFlipButton)
        }
        DGTConnectionToolbarContent(
            status: connection.status,
            identifier: AccessibilityID.boardConnectButton,
            isSheetPresented: $showConnectSheet
        )
        ToolbarSpacer()
        InspectorToggleContent(
            isPresented: $tabState.boardInspectorPresented,
            identifier: AccessibilityID.boardInspectorToggle
        )
    }
    
    // MARK: Board Surface

    /// Gap between bar and board. The *width* is deliberately not here - `EvaluationBarView.width`,
    /// stated once by the view that draws it (the two disagreed for a month).
    private static let evaluationBarGap: CGFloat = 10

    /// The score label's slot, trailing the bar. **Reserved, not measured**: the board's side derives
    /// from the leftover width, and a slot that tracked the text would resize the board per score.
    /// Being wrong here is a cosmetic clip, never a layout break.
    private static let evaluationLabelWidth: CGFloat = 38

    /// The board, shared by game view and live mirror - one place, so the identifier and modifier
    /// tail can't drift. Nil evaluation (the live branch's only value) renders no bar: the bar is
    /// review furniture, and live engine eval is assumed-never.
    private func boardSurface(
        position: Position,
        pieces: [ResolvedPiece],
        lastMove: LastMove?,
        checkSquare: Square?,
        ghostSquare: Square?,
        ghostPiece: Piece?,
        attentionSquares: Set<Square> = [],
        targetSquares: Set<Square> = [],
        hintSquares: Set<Square> = [],
        evaluation: EvaluationBarReading? = nil
    ) -> some View {
        let board = BoardView(
            position:         position,
            pieces:           pieces,
            style:            boardStyle,
            perspective:      tabState.boardPerspective,
            lastMove:         lastMove,
            checkSquare:      checkSquare,
            ghostSquare:      ghostSquare,
            ghostPiece:       ghostPiece,
            attentionSquares: attentionSquares,
            targetSquares:    targetSquares,
            hintSquares:      hintSquares
        )

        return Group {
            if let evaluation {
                GeometryReader { geometry in
                    // Board is square, takes the shorter axis after the bar column is reserved - reserved, not
                    // measured, so the board doesn't resize as the score changes width.
                    let reserved = EvaluationBarView.width
                        + Self.evaluationBarGap
                        + Self.evaluationLabelWidth
                    let side = max(0, min(
                        geometry.size.width - reserved,
                        geometry.size.height
                    ))

                    // Bar pinned to the destination's leading edge, board centred in what is left (by request).
                    ZStack {
                        board
                            .frame(width: side, height: side)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        HStack(spacing: Self.evaluationBarGap) {
                            EvaluationBarView(
                                reading: evaluation,
                                perspective: tabState.boardPerspective,
                                style: boardStyle
                            )
                            // Height only: the bar states its own width - framing it again re-opens the closed twin.
                            .frame(height: side)

                            // The always-visible label, in the gap, never on the bar - a thin losing share would swallow it.
                            Text(evaluation.label)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(
                                    width: Self.evaluationLabelWidth,
                                    alignment: .leading
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                board
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.board)
    }
    
    // MARK: Content
    
    private func content(pgn: PGN, game: Game) -> some View {
        // PGN-replay path: no ghost. Ghosts only make sense against the live physical board.
        boardSurface(
            position:    game.currentState.position,
            // Review arm: parity is total, every piece glides under its per-ply tracker identity.
            pieces:      PieceIdentity.resolved(
                position: game.currentState.position,
                tracker:  game.currentTracker
            ),
            lastMove:    game.lastMove,
            checkSquare: game.checkSquare,
            ghostSquare: nil,
            ghostPiece:  nil,
            // The bar exists iff `hasScoredPly` - **was** `!evaluations.isEmpty`, which is true of an
            // all-nil array: a pass that scored nothing drew a fabricated 50/50 bar.
            evaluation:  pgn.hasScoredPly
                ? EvaluationBarReading(game.currentEvaluation)
                : nil
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
                onMoveTapped: { index in game.jump(to: index + 1) }
            )
            .inspectorColumnWidth(min: 350, ideal: 350, max: 400)
        }
    }
    
    // MARK: Live Surface
    
    /// The live surface: mirror board, live inspector, resume/corrupt forks, archive confirmation.
    /// All status messaging lives in the sidebar panel; the stage above the board stays clear.
    private var liveSurface: some View {
        mirrorBoard
            .inspector(isPresented: $tabState.boardInspectorPresented) {
                liveInspector
                    .inspectorColumnWidth(min: 350, ideal: 350, max: 400)
            }
        // M4.3 resume offer - a modal fork, not a banner: resume-or-delete is a genuine either/or.
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
        // Corrupt-draft variant: resume off the table; "Keep for Now" leaves the file as diagnostics.
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
        // M5 archive confirmation. Auto-presents on success; dismissal acknowledges; the row stays editable.
            .sheet(isPresented: isArchiveConfirmationPresented) {
                if let pgn = session.archivedPGN {
                    EditGameInfoSheet(
                        pgn: pgn,
                        deduplicated: session.archiveOutcome == .deduplicated,
                        onSave: { roster in
                            applyEditedInfo(roster, to: pgn)
                            session.updateRoster(roster)
                        },
                        // Tag form into the field, `name` fallback - `NewLiveGameSheet`'s exact expression
                        // (a second spelling of "what a seat menu offers" is the twin-read-site pattern).
                        knownPlayers: knownPlayers.map { $0.tagName ?? $0.name }
                    )
                }
            }
    }
    
    /// Setter deliberately ignores dismissal: the offer is answered by its buttons, never by evasion -
    /// Resume-or-delete is a fork, not a suggestion.
    private var isResumeOfferPresented: Binding<Bool> {
        Binding(
            get: { session.resumableDraft != nil },
            set: { _ in }
        )
    }
    
    /// Presents the corrupt-draft alert until answered or deferred this visit.
    private var isCorruptDraftOfferPresented: Binding<Bool> {
        Binding(
            get: { session.pendingDraftIsCorrupt && !corruptOfferDeferred },
            set: { _ in }
        )
    }
    
    /// Resume alert body - plus a heads-up when the draft is already decided (resume triggers the
    /// M5 self-heal archive).
    private func resumeOfferMessage(for draft: LiveGameDraft) -> String {
        let plies = draft.sanMoves.count
        // An alert is a display surface: the draft stores tag form, so render through the transform.
        let pairing = "\(PlayerName.displayForm(of: draft.white)) vs \(PlayerName.displayForm(of: draft.black))"
        var lines = [
            "\(pairing), \(plies) \(plies == 1 ? "move" : "moves").",
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
    
    /// Presents while a *successful* outcome is unacknowledged; a failure never presents this sheet -
    /// it lives on the HUD as Retry-or-discard.
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
    
    /// Applies edited details through `PGNStore.applyEdit` (which owns the rehash structurally).
    /// Also renames the row when it still carried the default "White vs Black" name.
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
            Self.logger?.error(
                "Archive edit failed to persist: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// What ⌘I would open, or nil. Review before live, matching `body`'s branch. The live case
    /// carries nothing - a live game has no identifier until it archives (why the request is an enum).
    private var getInfoSubject: GetInfoRequest? {
        if let pgn = tabState.boardPGN { return .game(pgn.persistentModelID) }
        return session.liveGame == nil ? nil : .live
    }


    private var isNewGameSheetPresented: Binding<Bool> {
        Binding(
            get: {
                // Auto-offer presents only on the live branch; the manual request presents everywhere.
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
    
    /// Live-branch inspector: game details when one exists, otherwise a connection-aware hint -
    /// the toggle is never a dead switch on the mirror.
    @ViewBuilder
    private var liveInspector: some View {
        if let game = session.liveGame {
            LiveGameInspectorView(
                game: game,
                onUpdateRoster: { roster in
                    session.updateRoster(roster)
                    // Post-archive, Edit Details keeps the Library row in step too.
                    if let pgn = session.archivedPGN {
                        applyEditedInfo(roster, to: pgn)
                    }
                },
                onResign: { session.resign($0) },
                onAgreeDraw: { session.agreeDraw() },
                onDiscard: { session.discardGame() }
            )
        } else if connection.isConnected {
            InspectorEmptyState(
                title: "No Live Game",
                systemImage: "checkerboard.rectangle",
                message: "Start a game from the board to see its details and moves here.",
                identifier: AccessibilityID.liveInspectorNoGame
            )
        } else {
            // The former HUD `disconnected` banner, relocated with an action instead of a dead message.
            InspectorEmptyState(
                title: "No Board Connected",
                systemImage: "cable.connector.horizontal",
                message: "Connect your DGT board to record games live.",
                identifier: AccessibilityID.liveInspectorNoBoard
            )
        }
    }
    
    // MARK: Live Mirror
    
    /// The mirror whenever no game is loaded. The *position* always renders `physicalBoard`
    /// verbatim; identity comes from `PieceIdentity`'s mirror arm (proven moves glide,
    /// everything else fades). Only the *overlays* come from the live game.
    private var mirrorBoard: some View {
        let guidance = recoveryGuidance
        return boardSurface(
            position:         connection.physicalBoard,
            pieces:           PieceIdentity.resolved(
                physical: connection.physicalBoard,
                game:     session.liveGame?.currentState,
                tracker:  session.liveGame?.currentTracker
            ),
            lastMove:         session.liveGame?.lastMove,
            checkSquare:      session.liveGame?.checkSquare,
            ghostSquare:      session.castlingGhostSquare,
            ghostPiece:       session.castlingGhostPiece,
            attentionSquares: guidance?.attentionSquares ?? [],
            targetSquares:    guidance?.targetSquares ?? [],
            // Hints stand down whenever recovery chrome is up: two overlay vocabularies at once
            // would decorate one square with contradicting instructions. Live-mirror only - the
            // review board's pieces don't lift.
            hintSquares:      guidance == nil
                ? MoveHints.destinations(
                    for: session.liveGame?.currentState,
                    physical: connection.physicalBoard
                )
                : []
        )
    }
    
    /// Recovery overlays, recomputed per observable change so highlights shrink as squares are fixed -
    /// a 64-square diff per render is cheap. The sidebar's checklist computes its own
    /// (`RecoveryGuidance.current`: two computations, one spelling).
    private var recoveryGuidance: RecoveryGuidance? {
        .current(session: session, connection: connection)
    }
    
    // MARK: Loading
    
    /// Resolves `loadedGameID` to PGN + Game, cached on `tabState`. No-op when the cache matches -
    /// called from both `onAppear` and `onChange`, and a rebuild would lose scrub position.
    private func loadIfNeeded() {
        guard let id = loadedGameID else {
            Self.logger?.debug("Board load: no game selected, clearing")
            clearBoard(error: nil)
            return
        }
        
        // Live models only: a game deleted while this tab held it leaves a tombstone. Falling through
        // re-resolves and lands on the load-error card - the honest surface.
        if tabState.boardPGN?.persistentModelID == id,
           tabState.boardPGN?.isDeleted == false,
           tabState.boardGame != nil {
            Self.logger?.debug(
                "Board load: cache hit for '\(self.tabState.boardPGN?.name ?? "?", privacy: .public)', no reload"
            )
            return
        }

        Self.logger?.debug("Board load: resolving id \(String(describing: id), privacy: .public)")

        // Blessed id→model resolution + tombstone guard: `model(for:)` resurrects deleted ids, and
        // `as?` alone waves the ghost through.
        guard let loadedPGN = modelContext.model(for: id) as? PGN, !loadedPGN.isDeleted else {
            clearBoard(error: "The game could not be found in the library.")
            Self.logger?.error(
                "PGN lookup failed for id \(String(describing: id), privacy: .public)"
            )
            return
        }
        
        do {
            let newGame = try Game(pgn: loadedPGN)
            // The review cue, wired here rather than inside `Game.init` because the player is
            // an environment value and a model-layer type reaching for one is how a `Game` stops
            // being constructible from a preview. Strong capture: the App owns `BoardSounds` for the
            // process, and it holds no reference back.
            newGame.onStep = { boardSounds.play($0) }
            // The success path *sets* the cache - `clearBoard` is for the four failure exits only.
            tabState.boardPGN = loadedPGN
            tabState.boardGame = newGame
            tabState.boardLoadError = nil
            Self.logger?.info(
                "Opened game '\(loadedPGN.name, privacy: .public)' plies=\(loadedPGN.moves.count)"
            )
        } catch {
            // `Game.init` is `throws(BuildError)` with one case, so this arm is total.
            clearBoard(error: nil)
            switch error {
            case .invalidMove(let index, let san, let underlying):
                tabState.boardLoadError = "Move \(index + 1) couldn't be parsed."
                Self.logger?.error(
                            """
                            Game.init failed for \(loadedPGN.name, privacy: .public): \
                            move \(index + 1) (index \(index)) SAN '\(san, privacy: .public)' \
                            failed with \(String(describing: underlying), privacy: .public). \
                            Prior moves: [\(loadedPGN.moves.prefix(index).joined(separator: " "), privacy: .public)]
                            """
                )
            }
        }
    }
    
    private func clearBoard(error: String?) {
        tabState.boardPGN = nil
        tabState.boardGame = nil
        tabState.boardLoadError = error
    }
}
