import os
import SwiftData
import SwiftUI

/// Board destination. When `loadedGameID` is non-nil, looks up the PGN,
/// builds a `Game`, and renders the board + inspector. When nil, it still
/// shows a board — the live DGT mirror (`connection.physicalBoard`, empty
/// until a board is connected), which is the M1 raw-mirror surface. There
/// is no landing/error card; the board is always on screen.
///
/// The live branch carries the live game's last-move and check highlights over
/// the mirrored physical position, the new-game dialog (auto-offered on
/// start-position detection, or requested from the sidebar's session panel —
/// D15′ re-homed all status messaging there so the stage above the board stays
/// clear), the live inspector, the crash-safety resume offer forking Resume /
/// Delete on `session.pendingDraft`, and a 50%-opacity ghost rook on
/// `session.castlingGhostSquare` mid-castle. The PGN-replay branch deliberately
/// has none of it: live surfaces compare the *physical* board against the live
/// game's state, which is orthogonal to scrubbing a finished PGN.
///
/// `loadedGameID` is bound to the enclosing tab's `WindowGroup` value, so each
/// native tab holds its own game or none. Switching to Library does not clear
/// it — the game stays loaded and reappears on return.
///
/// **Per-tab state lives on `ContentView`'s `TabState`, not on this view.**
/// SwiftUI recreates this destination on every sidebar round-trip, so `@State`
/// here would lose scrub position, perspective and inspector toggle each time.
internal struct BoardDestination: View {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.boardload)
    
    // MARK: Bound State
    
    @Binding internal var loadedGameID: PersistentIdentifier?
    
    // MARK: Tab State (lives on enclosing `ContentView`)
    
    @Bindable internal var tabState: TabState
    
    // MARK: Environment
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(DGTConnection.self) private var connection
    @Environment(DGTLiveSession.self) private var session
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    
    // MARK: View State
    
    /// True after "Keep for Now" on the corrupt-draft alert, so it doesn't
    /// re-present every render for the rest of this visit. The file stays on
    /// disk as diagnostics; the offer returns at the next launch (or the
    /// next visit to Board). Transient by design — losing the deferral across
    /// a sidebar round-trip re-offers, which is the safe direction.
    @State private var corruptOfferDeferred = false
    
    /// The editors a *loaded* archived game can request from the review
    /// inspector. Transient by design, like `corruptOfferDeferred` — losing
    /// "sheet open" across a sidebar round-trip is fine.
    ///
    /// One optional rather than two booleans because the two are mutually
    /// exclusive by construction: both require `boardPGN`, and a click can
    /// only ask for one. Two booleans would hand the window's single modal
    /// slot a second way to be asked twice, for no gain.
    
    /// The connect dialog, lifted out of `DGTConnectionToolbarModifier` with
    /// the button. It was always one of the sheets contending for the window's
    /// single modal slot — the presentation-race note in `body` names it — it
    /// was just hidden inside a modifier.
    @State private var showConnectSheet = false
    
    /// Set by the Game menu's Get Info item, which cannot open a window
    /// itself; cleared as soon as this view has. A trigger rather than a
    /// stored request because the *subject* is already derivable here — see
    /// `getInfoSubject` — and publishing it upward only to have it handed
    /// back would give the menu a value it has no way to use.
    @State private var getInfoRequested = false

    /// The registry, for the archive sheet's seat pickers (5 Aug 2026).
    ///
    /// Queried *here* rather than in `EditGameInfoSheet` because that sheet is
    /// deliberately container-free — its previews build it with none, so a
    /// `@Query` inside it would trap the canvas. The destination has a context
    /// already; the sheet takes strings.
    ///
    /// Sorted by `name` (display form) to match `NewLiveGameSheet`'s query, so
    /// the two seat menus list players in the same order. The *inserted* value
    /// is still `tagName ?? name` — sorting by what a reader scans, inserting
    /// what the archive stores, which is D29′'s split.
    @Query(sort: \Player.name) private var knownPlayers: [Player]

    // `BoardEditor` and `activeEditor` are gone with D57′, and the enum's own
    // doc is why this is worth a comment rather than a silent deletion. It
    // argued for staying an enum at one case, on the grounds that "a second
    // editor is one case away". The traffic went the other way: M10 took the
    // movetext arm, D57′ took the info arm, and the type reached zero cases
    // without ever reaching two. Kept as a note because the argument was
    // sound — `.sheet(item:)` really is better than a `Bool` plus a subject —
    // and only the forecast was wrong.
    //
    // This destination presents no editor now. The live branch's sheets
    // (new-game, archive) are separate state and unaffected.

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
        // The subtitle is *state*; the title above is identity and the
        // inspector's `GameHeadline` below is the pairing. Branching on
        // `boardPGN` mirrors the body's own branch at the top of this
        // property: a review tab reports the position it is showing, a live
        // tab reports the physical board. Never both — a tab reviewing a PGN
        // has no business announcing a desync it isn't party to (D15′).
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
        // The review inspector's metadata editor stood here from M-lib until
        // D57′, and it is the third and last editing surface this destination
        // has shed. M10 took the live movetext pencil, D54′ recorded why the
        // review one went with it, and D57′ takes Edit Info: an archived game's
        // roster is edited in Get Info's Details tab, reached by ⌘I from any
        // row or from the Game menu rather than from a header control on a
        // panel the reader has to already have open.
        //
        // The through-line across all three is D53′'s, and it is worth stating
        // once now that it has finished: the Board is a *reading* surface. It
        // renders a position, a curve and a move list, and every verb that
        // rewrites bytes has moved to the thing being rewritten.
        //
        // `applyEditedInfo` stays — the live and archive paths are its other
        // two callers, and they write through the same door.
        // Phase 11: publish the active game so GameNavigationCommands' arrow
        // keys can scrub it.
        .focusedSceneValue(\.activeGame, tabState.boardGame)
        // …and the Get Info trigger, published only when this tab has a
        // subject, so the menu item's `disabled(_:)` reads a condition that is
        // genuinely producible both ways: a live tab with no recording and no
        // loaded PGN publishes nil.
        .focusedSceneValue(
            \.boardGetInfoRequest,
            getInfoSubject == nil ? nil : $getInfoRequested
        )
        // The menu asks, this opens. Cleared before opening rather than after,
        // so a second ⌘I is a fresh request rather than a no-op against a flag
        // that is still true.
        .onChange(of: getInfoRequested) { _, requested in
            guard requested else { return }
            getInfoRequested = false
            if let subject = getInfoSubject { openWindow(value: subject) }
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: loadedGameID) { _, _ in loadIfNeeded() }
    }
    
    // MARK: Toolbar
    
    /// One stream, in written order. Items merged from separate `.toolbar`
    /// modifiers arrive without a region boundary SwiftUI can act on: the
    /// toolbar stays undivided, the `.inspector` column tucks beneath it
    /// instead of running full height, and left-to-right order becomes an
    /// accident of modifier nesting rather than something written down. Board
    /// had three streams and all three symptoms. The Library always had one,
    /// and was the only destination that ever looked right.
    @ToolbarContentBuilder
    private var boardToolbarContent: some ToolbarContent {
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

    /// The gap between the evaluation bar and the board (M3, D33′).
    ///
    /// The *width* is deliberately not here: it is `EvaluationBarView.width`,
    /// stated once by the view that draws it. This constant briefly had a
    /// sibling — `evaluationBarWidth = 16` — while the view framed itself at
    /// 20, and the two never met. The gap stays here because it describes a
    /// relationship between two views rather than either one of them.
    private static let evaluationBarGap: CGFloat = 10

    /// The slot the score label occupies, trailing of the bar (7 Aug 2026).
    ///
    /// **Reserved, not measured**, and that is the decision rather than a
    /// shortcut. The board's side length is derived from the width left over
    /// after this column, so a slot that grew and shrank with the text would
    /// resize the *board* every time the evaluation crossed a digit — a
    /// board that breathes as the score moves between `0.0` and `-12.3`.
    ///
    /// Sized for the widest thing `EvaluationBarReading.label` can produce: a
    /// signed two-digit pawn score to one decimal (`-12.3`), which is longer
    /// than any mate spelling (`#-9`). At `.caption` monospaced digits that is
    /// comfortably inside 38 pt; the label truncates rather than pushing, so
    /// being wrong here is a cosmetic clip and not a layout break.
    ///
    /// Here rather than on `EvaluationBarView` for the reason the gap is here:
    /// the bar no longer draws the label, so this describes a relationship
    /// between the bar and the board and belongs to neither.
    private static let evaluationLabelWidth: CGFloat = 38

    /// The board itself, shared by the game view and the live mirror. Both
    /// render the same `BoardView` with the same padding, sizing, and
    /// `"board"` accessibility identifier — only the inputs differ. Keeping
    /// this in one place means the identifier and the modifier tail can't
    /// drift between the two branches.
    ///
    /// `evaluation` (M3, D33′) hangs the vertical eval bar on the board's
    /// leading edge. Nil — the default, and the only value the live branch
    /// ever passes — renders the board exactly as before: the bar is
    /// review-surface furniture, and a live game never shows one (no live
    /// engine eval, assumed-never). The `BoardView` is built once and
    /// placed by whichever branch runs, so the eleven inputs can't drift
    /// between them. The explicit `GeometryReader` math exists because
    /// `BoardView` is strictly square (`aspectRatio(1, .fit)`): a plain
    /// `HStack` would give the bar the container's full height while the
    /// board fits square inside it — the bar must borrow the *board's*
    /// side, which only this computation knows.
    private func boardSurface(
        position: Position,
        pieces: [ResolvedPiece],
        lastMove: LastMove?,
        checkSquare: Square?,
        ghostSquare: Square?,
        ghostPiece: Piece?,
        attentionSquares: Set<Square> = [],
        targetSquares: Set<Square> = [],
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
            targetSquares:    targetSquares
        )

        return Group {
            if let evaluation {
                GeometryReader { geometry in
                    // The board is square and takes whatever the shorter axis
                    // allows once the bar column is reserved. The column is the
                    // bar, the gap, and the widest the label can get — reserved
                    // rather than measured, so the board does not resize as the
                    // score changes width between "0.0" and "-12.3".
                    let reserved = EvaluationBarView.width
                        + Self.evaluationBarGap
                        + Self.evaluationLabelWidth
                    let side = max(0, min(
                        geometry.size.width - reserved,
                        geometry.size.height
                    ))

                    // **Bar pinned to the destination's leading edge, board
                    // centred in what is left** (7 Aug 2026, by request). The
                    // bar used to sit immediately beside the board and travel
                    // with it as the window resized; it now stays put and the
                    // board moves, which is what "far leading side" means.
                    //
                    // A `ZStack` rather than an `HStack`, and the reason is the
                    // centring: in an `HStack` the board's centre is the centre
                    // of *what is left over*, so it drifts off the window's
                    // centre by half the bar column. Two overlays each taking
                    // their own alignment let the board be centred in the whole
                    // surface while the bar is pinned to the edge of it.
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
                            // Height only: the bar states its own width, so
                            // framing it here again would re-open the twin that
                            // `EvaluationBarView.width` exists to close.
                            //
                            // `side` exactly — the bar is now the board's
                            // height rather than the board's height *minus a
                            // label*, which is what it was while the label
                            // shared its stack (see `EvaluationBarView`).
                            .frame(height: side)

                            // D33′'s always-visible label, rehoused. Vertically
                            // centred against the bar and sitting in the gap,
                            // never on the bar: a thin losing share would
                            // swallow it, which is the objection D33′ raised
                            // when it put the label below instead.
                            //
                            // Fixed width so the board's geometry above is a
                            // constant. Leading-aligned inside that width, so
                            // the text starts at a fixed distance from the bar
                            // instead of creeping toward it as the score
                            // shortens.
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
        // PGN-replay path: no ghost. Ghosts only make sense against the
        // live physical board.
        boardSurface(
            position:    game.currentState.position,
            // Review arm: the rendered position is the game's position, so
            // parity is total and every piece glides under its per-ply
            // tracker identity — stepping, jumping, and the perspective flip
            // all animate from the same resolution.
            pieces:      PieceIdentity.resolved(
                position: game.currentState.position,
                tracker:  game.currentTracker
            ),
            lastMove:    game.lastMove,
            checkSquare: game.checkSquare,
            ghostSquare: nil,
            ghostPiece:  nil,
            // M3 (D33′): the bar exists iff the game carries analysis, which
            // is `hasScoredPly` and **was** `!evaluations.isEmpty` until
            // 7 Aug 2026. The old spelling is true of an all-nil array, so a
            // pass that scored nothing drew a full-height bar pinned at dead
            // even — a fabricated 50/50, not an absence. The comment here
            // used to call `isEmpty` "the `hasAnalysis` projection's exact
            // truth"; it still is, and that projection is asking the same
            // wrong question (see the note at `PGN.hasScoredPly`).
            //
            // Per-ply nil (ply 0, a skipped ply inside a scored game) still
            // folds to the neutral reading inside `EvaluationBarReading`,
            // matching the graph's `?? 0.5` below — that fallback is right
            // *within* an analysed game and only wrong as a stand-in for the
            // whole of one.
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
                    .inspectorColumnWidth(min: 350, ideal: 350, max: 400)
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
                        },
                        // D29′: tag form into the field, `name` as the fallback
                        // for a pre-backfill row — `NewLiveGameSheet`'s exact
                        // expression, because a second spelling of "what a seat
                        // menu offers" is the twin-read-site pattern.
                        knownPlayers: knownPlayers.map { $0.tagName ?? $0.name }
                    )
                }
            }
    }
    
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
            Self.logger?.error(
                "Archive edit failed to persist: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
    
    // `applyEditedMovetext` lived here until M10 and is now
    // `LibraryDestination`'s, with the door that calls it. What it did that
    // the Library's copy does not need: rebuild the cached on-board `Game`,
    // because the moves had changed underfoot and `loadIfNeeded`'s cache guard
    // would otherwise skip the reload. That rebuild is the one piece of this
    // destination the move deliberately left behind — and it is also the
    // recorded cost of editing from the Library while the same game sits on a
    // board, since a Board window in another tab holds its own `TabState` and
    // will keep showing the pre-edit moves until it reloads.

    /// What the Game menu's ⌘I would open, or nil if this tab has no subject.
    ///
    /// Review before live, matching `body`'s own branch: a tab showing a
    /// loaded PGN describes that game even while a recording is in progress
    /// elsewhere in the session. The live case carries nothing because a live
    /// game has no `PersistentIdentifier` until it archives — `GetInfoRequest`
    /// is an enum rather than a struct with an optional id for exactly that
    /// asymmetry.
    private var getInfoSubject: GetInfoRequest? {
        if let pgn = tabState.boardPGN { return .game(pgn.persistentModelID) }
        return session.liveGame == nil ? nil : .live
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
            InspectorEmptyState(
                title: "No Live Game",
                systemImage: "checkerboard.rectangle",
                message: "Start a game from the board to see its details and moves here.",
                identifier: AccessibilityID.liveInspectorNoGame
            )
        } else {
            // The former HUD `disconnected` banner, relocated: this empty
            // state used to say "start a game from the board" — impossible
            // advice with no board — while the banner spent the strip
            // above the board on a message with no action.
            InspectorEmptyState(
                title: "No Board Connected",
                systemImage: "cable.connector.horizontal",
                message: "Connect your DGT board to record games live.",
                identifier: AccessibilityID.liveInspectorNoBoard
            )
        }
    }
    
    // MARK: Live Mirror
    
    /// The board shown whenever no game is loaded. The *position* always
    /// renders the DGT connection's live `physicalBoard` (empty when nothing
    /// is connected). Identity comes from `PieceIdentity`'s mirror arm —
    /// M6's tracker-parity work, which this doc spent M3 through M5 calling
    /// "a v1.x item": per-square parity against the live game's last
    /// committed position keeps settled pieces under their real identities,
    /// the reconstructor's own verification proves the in-flight move's, and
    /// anything neither can vouch for renders anonymous — present, correct,
    /// and unable to glide. The feared mis-key is structurally out: a square
    /// whose physical piece disagrees with the game's never inherits the
    /// stale identity. Occupancy stays the physical board, verbatim, always;
    /// with no live game every piece is anonymous and the mirror behaves
    /// exactly as it did before M6. Only the *overlays* come from the live
    /// game (M3.2): last-move and check highlights, plus the mid-castle
    /// ghost rook from the session. The check highlight keys off the legal
    /// game state, so mid-move it can sit on a square the king has
    /// physically just left — same accepted tradeoff, resolved at the next
    /// settle.
    private var mirrorBoard: some View {
        boardSurface(
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
            attentionSquares: recoveryGuidance?.attentionSquares ?? [],
            targetSquares:    recoveryGuidance?.targetSquares ?? []
        )
    }
    
    /// The board's attention/target overlays while `recovering` (M6.2), nil
    /// otherwise. Recomputed on every observable change of
    /// `connection.physicalBoard`, so highlights shrink as squares are fixed —
    /// a 64-square diff per render is cheap (reach for `.task(id:)`
    /// memoization only if profiling ever demands it). The sidebar's checklist
    /// recomputes its own; see `RecoveryGuidance.current` for why that is two
    /// computations and no longer two spellings.
    private var recoveryGuidance: RecoveryGuidance? {
        .current(session: session, connection: connection)
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
            Self.logger?.debug("Board load: no game selected, clearing")
            clearBoard(error: nil)
            return
        }
        
        // The cache honors live models only: a game deleted from the Library
        // while this tab held it open (same window via the sidebar, or any
        // other window) leaves `boardPGN` a tombstone whose attribute reads
        // are stale at best. Falling through re-resolves, and the guard
        // below lands on the load-error card — the honest surface for "this
        // game is gone" (30 July audit; was pinned by the load-error UITest
        // until the suite retired, D51′ — the manual checklist owns it now).
        if tabState.boardPGN?.persistentModelID == id,
           tabState.boardPGN?.isDeleted == false,
           tabState.boardGame != nil {
            Self.logger?.debug(
                "Board load: cache hit for '\(self.tabState.boardPGN?.name ?? "?", privacy: .public)', no reload"
            )
            return
        }

        Self.logger?.debug("Board load: resolving id \(String(describing: id), privacy: .public)")

        // The blessed id→model resolution plus the tombstone guard — the
        // `AnalysisQueueController.run()` pattern: `model(for:)` happily
        // resurrects an instance for a deleted id, and `as?` alone would
        // wave the ghost through to `Game.init`.
        guard let loadedPGN = modelContext.model(for: id) as? PGN, !loadedPGN.isDeleted else {
            clearBoard(error: "The game could not be found in the library.")
            Self.logger?.error(
                "PGN lookup failed for id \(String(describing: id), privacy: .public)"
            )
            return
        }
        
        do {
            let newGame = try Game(pgn: loadedPGN)
            // The success path *sets* the cache — `clearBoard` is for the
            // four failure exits only. Sharing the helper here threw the
            // freshly built game away and nilled the tab state, so a load
            // logged success and rendered the live mirror.
            tabState.boardPGN = loadedPGN
            tabState.boardGame = newGame
            tabState.boardLoadError = nil
            Self.logger?.info(
                "Opened game '\(loadedPGN.name, privacy: .public)' plies=\(loadedPGN.moves.count)"
            )
        } catch {
            // `Game.init` is `throws(BuildError)` and `BuildError` has exactly
            // one case, so this arm is total: the old `else` guarded a case
            // that doesn't exist, and the trailing untyped `catch` below it was
            // unreachable. The `parseSAN` typed-throws lesson, one layer up.
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
