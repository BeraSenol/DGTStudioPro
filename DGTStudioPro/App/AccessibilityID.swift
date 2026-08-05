//  TARGET MEMBERSHIP: DGTStudioPro only since D51′. This file used to compile
//  into DGTStudioProUITests too, and the dual membership was the entire point
//  (F8) — identifiers were a tested contract, and it held at compile time only
//  if both sides read the same constants. The suite went; the membership with it.
//
//  Two consequences.
//
//  1. The `String`-only signatures below are unenforced now. Every function
//     takes a raw value rather than an app type, because a signature naming an
//     app type compiled in the app and broke the UI test target. Left alone on
//     purpose: changing sixteen signatures to buy type safety nothing checks is
//     churn. Recorded because a constraint obeyed by every instance and
//     explained by none reads as taste — which is how it got broken once.
//
//  2. **These identifiers have no automated consumer at all.** They are applied
//     across the view layer and nothing reads them — `accessibilityIdentifier`
//     is not surfaced to VoiceOver; that is `accessibilityLabel`, set
//     separately and still live. Kept because sweeping the registry and its
//     call sites is a large mechanical diff for no functional gain, and because
//     they are what a future UI suite or accessibility audit needs on day one.
//     A stated bet, not an oversight.
//
//     No count appears here: D42′ moved the registry's size into a grep so it
//     could not go stale in prose, and it had gone stale in three places at
//     once. The grep is not quoted here either — it counts declaration keywords
//     in this file, so pasting it here adds a match to its own result. D42′
//     owns the command.
//
//  The rot this fixed was real and is why the discipline exists: the UI suite
//  once asserted the *absence* of "board.error" while the app shipped the
//  banner as "board.loaderror". An absence assertion against a stale name
//  passes forever while guarding nothing.
//
//  A raw identifier string in a view is still a defect; the enforcement is a
//  grep for the modifier followed by a quote, over production sources. Named
//  rather than spelled, per D43′ — the token verbatim would make this file a
//  permanent hit in the grep it describes.
//

/// The app's accessibility-identifier registry. Dotted lowercase throughout.
///
/// Renaming one is no longer a compile-time breaking change — the target that
/// made it one is gone (see the file header) — so renames are now checked by
/// nothing but reading. Treat them as the stable contract they were.
internal enum AccessibilityID {
    
    // MARK: Shell
    
    internal static let sidebar = "sidebar"
    
    /// `sidebar.board`, `sidebar.library`, … — one per `Destination`
    /// raw value. Takes the raw string (not the enum) — the String-only
    /// rule this file kept after the UI suite left (D51′; see the header).
    internal static func sidebarDestination(_ rawValue: String) -> String {
        "sidebar.\(rawValue)"
    }
    
    /// `sidebar.tag.Checkmate`, … — one per `SmartTag`, keyed by the
    /// tag's *name* since M-prs.5 (the enum and its raw values are gone;
    /// the `gameCard(_:)` display-name precedent applies).
    internal static func sidebarTag(_ name: String) -> String {
        "sidebar.tag.\(name)"
    }
    
    internal static let sidebarTagsAdd = "sidebar.tags.add"
    
    /// Session panel (M-ux.3, D15′) — the sidebar's pinned session
    /// surface. `sidebar.loaderror` / `.dismiss` are the former
    /// `board.loaderror` family: the M8.2 *behavior* is unchanged, only
    /// its surface moved, and the identifiers travelled with it — a
    /// deliberate breaking rename, executed here (the registry) with the
    /// UITest re-targeted in the same change.
    internal static let sessionPanel            = "sidebar.session"
    internal static let sidebarLoadError        = "sidebar.loaderror"
    internal static let sidebarLoadErrorDismiss = "sidebar.loaderror.dismiss"
    
    // MARK: Tag Editor (M-prs.5)
    
    internal static let tagsEditor       = "tags.editor"
    internal static let tagsEditorName   = "tags.editor.name"
    internal static let tagsEditorSave   = "tags.editor.save"
    internal static let tagsEditorCancel = "tags.editor.cancel"
    
    // MARK: Board
    
    internal static let board                = "board"
    internal static let boardFlipButton      = "board.flipButton"
    internal static let boardInspectorToggle = "board.inspectorToggle"
    /// The M3 evaluation bar (D33′) — present only on the review surface
    /// over an analysed game, so tests asserting absence on live/unanalysed
    /// boards have a stable handle too.
    internal static let boardEvaluationBar   = "board.evaluationBar"

    // MARK: Evaluation Magnifier (M8, D46′)

    /// The magnifying glass in both Evaluation section headers, and the three
    /// parts of the window it opens.
    ///
    /// One identifier for the button across two inspectors, unlike the Edit
    /// Info / Edit Details pair which deliberately have their own: those are
    /// two buttons doing the same *kind* of thing to two different subjects,
    /// while these two open literally the same window onto the same game. A
    /// second identifier would be asserting a difference that isn't there.
    internal static let evaluationMagnifier     = "evaluation.magnifier"
    internal static let evaluationWindowGraph   = "evaluation.window.graph"
    internal static let evaluationWindowReadout = "evaluation.window.readout"
    internal static let evaluationWindowEmpty   = "evaluation.window.empty"
    /// The toolbar's connect control (`DGTConnectionToolbar`). Migrated
    /// late (M-ux.3): the value lived as a *parameter default*, which the
    /// enforcement grep described in this file's header cannot see —
    /// defaults and helper arguments need the same discipline as direct
    /// call sites.
    internal static let boardConnectButton = "board.connectButton"
    
    /// `square.e4`, … — one per mirror square, keyed by algebraic
    /// notation (the stable handle for keyboard-nav and highlight
    /// assertions). Byte-identical to the file/rank-character
    /// construction it replaced: `Square.algebraicNotation` builds from
    /// the same `%8`/`/8` ASCII arithmetic, pinned by `SquareTests`.
    internal static func boardSquare(_ algebraic: String) -> String {
        "square.\(algebraic)"
    }
    
    // MARK: Movetext Editor (M-lib.3, D18′)

    /// The movetext editor's five controls. Never Board-specific: they name the
    /// editor's *contents*, the same from whichever door opens it — today Get
    /// Info's Move Text tab, whose host identifier is `getinfo.game.movetext`.
    ///
    /// **Four removals rhyme through this group, and they are one decision
    /// arriving in instalments** — a pencil on a panel giving way to a door on
    /// the thing itself: `board.editMoves` (M10 → `library.editMoves`),
    /// `players.inspector.rename` (D53′ → `getinfo.player.tag`),
    /// `board.editInfo` (D57′ → the `getinfo.game.field.*` family), and
    /// `library.editMoves` (D59′, one day after being minted as a successor).
    /// Recorded rather than done quietly: a removal is as breaking as a rename.
    ///
    /// The fourth has **no successor control**, which is the finding. The other
    /// three swapped one control's identifier for another's; this one is
    /// reached by selecting a tab, so the addressable part is these five
    /// contents — which never moved. The group shrank by one without losing
    /// coverage, because the pencil was only the way in.
    ///
    /// Consequence, named so the next sweep reads it as measured rather than
    /// missed: `InspectorEditButtonView` is down to **one** production consumer,
    /// the live inspector's Edit Details. Not dead and not to be swept, but a
    /// shared component with a single caller is where "shared" starts describing
    /// history rather than structure.
    ///
    /// All five are reachable in a boardless run, so a future XCUITest can
    /// harden them; for now the validator and store suites are the contract.
    internal static let movetextEditorSheet    = "movetext.editor"
    internal static let movetextEditorField    = "movetext.editor.field"
    internal static let movetextEditorStatus   = "movetext.editor.status"
    internal static let movetextEditorSave     = "movetext.editor.save"
    internal static let movetextEditorCancel   = "movetext.editor.cancel"

    // MARK: Get Info (M10)

    /// The window behind every inspector's subject, and the gestures that open
    /// it.
    ///
    /// **Three window identifiers, not one**, which is the opposite call from
    /// `evaluationMagnifier` one group up and for the reason that entry
    /// states: the magnifier's two buttons open literally the same window onto
    /// the same game, so a second identifier would assert a difference that
    /// isn't there. These three are one window rendering three *different
    /// subjects* — a game, a recording, a player — and a check that found the
    /// player form where it expected the game form should fail rather than
    /// pass on a shared handle.
    ///
    /// The menu item takes its own identifier despite being the same verb as
    /// the two context-menu items: it is the Board's only door (⌘I plus the
    /// Game menu — the Board has one subject and no list to right-click), so
    /// it is the one that can break independently. It named a control that did
    /// not exist for the length of M10 — minted against a doc sentence rather
    /// than against a built item, which the 4 Aug review caught; the Game menu
    /// carries it now.
    ///
    /// ~~`getinfo.player.tag` is the one *editable* control in the window~~ —
    /// **false since D57′**, which made the seven roster tags editable and gave
    /// them `getInfoGameField(_:)`. The sentence is corrected rather than
    /// deleted because it dated precisely: it was written at M10 as a
    /// description of the code and was true for one day.
    ///
    /// `getinfo.game` now names the **tab container**, with
    /// `getinfo.game.details` and `getinfo.game.file` naming the two tabs
    /// beneath it. That is a widening rather than a rename — the old identifier
    /// still resolves to the game form's root — so it takes no successor entry,
    /// unlike the removals below.
    ///
    /// The live form stays `LabeledContent` throughout and keeps a single
    /// form-level identifier, which is all there is to address on it.
    internal static let getInfoGame          = "getinfo.game"
    internal static let getInfoGameDetails   = "getinfo.game.details"
    /// The third tab (5 Aug 2026), holding D18′'s movetext editor. Its
    /// *contents* keep the five `movetext.editor.*` identifiers below — the
    /// editor moved container and kept its addresses, which is what makes this
    /// a new host rather than a new surface.
    internal static let getInfoGameMoveText  = "getinfo.game.movetext"
    internal static let getInfoGameFile      = "getinfo.game.file"

    /// The seat menus on the Details tab (5 Aug 2026). A function over the
    /// seat's raw string, not over `SevenTagRoster` — the file's String-only
    /// signature rule, whose reason is recorded in this file's header.
    internal static func getInfoSeatPicker(_ seat: String) -> String {
        "getinfo.game.seatPicker.\(seat)"
    }
    internal static let getInfoLive          = "getinfo.live"
    internal static let getInfoPlayer        = "getinfo.player"
    internal static let getInfoPlayerTagField = "getinfo.player.tag"
    internal static let getInfoEmpty         = "getinfo.empty"
    internal static let getInfoBoardMenuItem = "getinfo.menuitem.board"

    /// One editable roster row on the Details tab (D57′).
    ///
    /// A function over the tag name rather than seven constants, the
    /// `getInfoMenuItem` shape: these are one control repeated per tag, and the
    /// tag is what distinguishes them. Takes a raw lowercased `String` for the
    /// reason the file's header gives — and note the call sites pass
    /// `SevenTagRoster`-shaped words without passing the enum itself, which is
    /// that same rule holding under a case where the typed version would have
    /// been easy and wrong: `Result` and `Date` are rows here but not text
    /// fields, so the enum this would have taken (`GetInfoWindow.GameField`)
    /// does not have a case for every identifier minted.
    internal static func getInfoGameField(_ tag: String) -> String {
        "getinfo.game.field.\(tag)"
    }

    /// The context-menu item, per destination. A function rather than two
    /// constants because the item is one verb reached from two row types, and
    /// the destination is what distinguishes them — the `sidebarDestination`
    /// shape.
    ///
    /// Takes a raw `String` like everything else in this file. The reason is
    /// no longer shared target membership (D51′ deleted the UI test target),
    /// but the rule outlived it deliberately: re-typing these signatures buys
    /// type safety nothing now checks.
    internal static func getInfoMenuItem(_ destinationRawValue: String) -> String {
        "getinfo.menuitem.\(destinationRawValue)"
    }

    // MARK: Live
    
    /// HUD (M3.1). The container's identifier names the phase — a closed
    /// set, so these are constants rather than a suffix-taking helper:
    /// the suffixes are exactly the strings a helper would scatter back
    /// to the call sites.
    internal static let liveHUDReconnecting  = "live.hud.reconnecting"
    internal static let liveHUDIdle          = "live.hud.idle"
    internal static let liveHUDAwaitingSetup = "live.hud.awaitingsetup"
    internal static let liveHUDPlaying       = "live.hud.playing"
    internal static let liveHUDCorrection    = "live.hud.correction"
    internal static let liveHUDRecovering    = "live.hud.recovering"
    internal static let liveHUDFinished      = "live.hud.finished"
    internal static let liveHUDArchiveFailed = "live.hud.archivefailed"
    internal static let liveHUDNewGame       = "live.hud.newgame"
    internal static let liveHUDRetryArchive  = "live.hud.retryarchive"
    
    internal static let liveInspector            = "live.inspector"
    internal static let liveInspectorEditDetails = "live.inspector.editdetails"
    internal static let liveInspectorResign      = "live.inspector.resign"
    internal static let liveInspectorDraw        = "live.inspector.draw"
    internal static let liveInspectorDiscard     = "live.inspector.discard"
    
    /// The live inspector's two empty states (D26′). Constants rather than a
    /// suffix-taking helper for the `liveHUD*` reason: a closed set whose
    /// suffixes a helper would only scatter back to the call sites.
    internal static let liveInspectorNoGame      = "live.inspector.nogame"
    internal static let liveInspectorNoBoard     = "live.inspector.noboard"
    
    internal static let liveNewGameSheet  = "live.newgame.sheet"
    internal static let liveNewGameStart  = "live.newgame.start"
    internal static let liveNewGameNotNow = "live.newgame.notnow"
    
    /// The `live.` prefix is now narrower than the truth: `EditLiveGameDetailsSheet`
    /// is presented from the Board's *review* inspector too, over an archived
    /// PGN seeded into a `LiveGame.Roster`. Shared sheet, shared identifiers —
    /// correct, because the two callers can never coexist (one branch has a
    /// live game and no PGN, the other has a PGN and no live game). The type's
    /// name has the same problem; renaming it is a mechanical change and
    /// travels alone.
    internal static let liveEditDetailsSheet  = "live.editdetails.sheet"
    internal static let liveEditDetailsSave   = "live.editdetails.save"
    internal static let liveEditDetailsCancel = "live.editdetails.cancel"
    
    internal static let liveRecoveryPanel         = "live.recovery.panel"
    internal static let liveRecoveryCount         = "live.recovery.count"
    internal static let liveRecoveryExport        = "live.recovery.export"
    internal static let liveRecoveryRestoredFlash = "live.recovery.restoredflash"
    
    /// `live.recovery.item.e4`, … — one checklist row per square, keyed
    /// by algebraic notation.
    internal static func liveRecoveryItem(_ algebraic: String) -> String {
        "live.recovery.item.\(algebraic)"
    }
    
    // MARK: Details Form (shared live/archive)
    
    /// The six roster-form fields render under their host's prefix:
    /// `live.form.*` in the live sheets (the default), `archive.form.*`
    /// when `EditGameInfoSheet` embeds the same form. The prefix is the
    /// only variance, so one helper per field keeps each suffix in
    /// exactly one place. The prefix stays a plain `String` — the
    /// registry's raw-string philosophy (the UI-test target can't see
    /// app types).
    internal static let liveFormPrefix    = "live.form"
    internal static let archiveFormPrefix = "archive.form"
    internal static func formWhite(_ prefix: String) -> String { "\(prefix).white" }
    internal static func formBlack(_ prefix: String) -> String { "\(prefix).black" }
    internal static func formEvent(_ prefix: String) -> String { "\(prefix).event" }
    internal static func formSite(_ prefix: String)  -> String { "\(prefix).site" }
    internal static func formDate(_ prefix: String)  -> String { "\(prefix).date" }
    internal static func formRound(_ prefix: String) -> String { "\(prefix).round" }
    /// The seat pickers' menu buttons (M-lib.1, D16′) — present only when
    /// the host supplies known players (the New Game sheet does; the edit
    /// sheets currently don't). Their functional witness is the manual
    /// checklist: the sheet is unreachable in a boardless UI run.
    internal static func formWhitePicker(_ prefix: String) -> String { "\(prefix).white.picker" }
    internal static func formBlackPicker(_ prefix: String) -> String { "\(prefix).black.picker" }
    
    // MARK: Archive Confirmation (M5)
    
    internal static let archiveSheet = "archive.sheet"
    internal static let archiveSave  = "archive.save"
    internal static let archiveDone  = "archive.done"
    
    // MARK: DGT Connection
    
    // `dgt.deviceList`, `dgt.rescanButton` and `dgt.connectButton` were
    // **removed** 2 Aug 2026 with the device picker (removals are as
    // breaking as renames — the D40′ precedent): the window connects to the
    // one hardcoded board or explains why it can't, so there is nothing to
    // list, rescan, or confirm. `dgt.notFoundPanel` is the successor state.
    internal static let dgtConnectSheet           = "dgt.connectSheet"
    internal static let dgtConnectingPanel        = "dgt.connectingPanel"
    internal static let dgtReconnectingPanel      = "dgt.reconnectingPanel"
    internal static let dgtConnectedPanel         = "dgt.connectedPanel"
    internal static let dgtFailedPanel            = "dgt.failedPanel"
    internal static let dgtNotFoundPanel          = "dgt.notFoundPanel"
    internal static let dgtCancelButton           = "dgt.cancelButton"
    internal static let dgtStopReconnectingButton = "dgt.stopReconnectingButton"
    internal static let dgtDisconnectButton       = "dgt.disconnectButton"
    internal static let dgtRetryButton            = "dgt.retryButton"
    
    // MARK: Settings
    
    internal static let settingsAutoConnectToggle      = "settings.autoConnectToggle"
    internal static let settingsEraseLibraryButton     = "settings.eraseLibraryButton"
    internal static let settingsIllegalMoveSoundToggle = "settings.illegalMoveSoundToggle"
    internal static let settingsPreventSleepToggle     = "settings.preventSleepToggle"
    internal static let settingsBoardCoordinatesToggle = "settings.boardCoordinatesToggle"
    internal static let settingsEngineDepthStepper     = "settings.engineDepthStepper"
    internal static let settingsEngineHashPicker       = "settings.engineHashPicker"
    internal static let settingsEngineThreadsStepper   = "settings.engineThreadsStepper"
    internal static let settingsPieceAnimationSlider   = "settings.pieceAnimationSlider"
    
    // MARK: Library
    
    internal static let libraryContent         = "library.content"
    internal static let libraryEmptyState      = "library.emptyState"
    internal static let libraryModeIcons       = "library.mode.icons"
    internal static let libraryModeList        = "library.mode.list"
    internal static let libraryModeColumns     = "library.mode.columns"
    internal static let libraryModeGallery     = "library.mode.gallery"
    internal static let libraryViewModePicker  = "library.viewModePicker"
    internal static let libraryImportButton    = "library.importButton"
    internal static let libraryAnalyzeButton   = "library.analyzeButton"
    internal static let libraryDeleteButton    = "library.deleteButton"
    internal static let libraryGamesTable      = "library.gamesTable"
    internal static let libraryInspectorToggle = "library.inspectorToggle"
    /// D26′ — the shared `InspectorEmptyState`. Distinct from
    /// `libraryEmptyState`, which is the *content area* with no games at all.
    internal static let libraryInspectorEmpty  = "library.inspector.empty"
    /// The multi-selection variant of the above (2 Aug 2026): 2+ games
    /// selected, the inspector names the count instead of detailing an
    /// arbitrary member.
    internal static let libraryInspectorMulti  = "library.inspector.multi"
    
    /// The rename pencil, which moved onto the roster section header when the
    /// header became the game's own name. It edits `PGN.name` — a user label
    /// outside the content hash — not a tag, so it is deliberately not part
    /// of the `board.editInfo` / `live.inspector.editdetails` family even
    /// though all three are now the same glyph in the same place.
    internal static let libraryInspectorRename = "library.inspector.rename"

    /// Review, as a glyph in the roster header (M10). Its own identifier
    /// rather than sharing with the Evaluation section's `Review` button
    /// despite the identical action: two controls in two headers are two
    /// controls, and a check that found one where it expected the other
    /// should fail. The `boardEditInfo` / `liveInspectorEditDetails` reasoning
    /// — the opposite call from `evaluationMagnifier`, which shares one
    /// identifier across two inspectors because it opens literally the same
    /// window.
    internal static let libraryInspectorReviewGlyph = "library.inspector.reviewGlyph"
    
    /// The raw-PGN section: the text itself, and the copy affordance in its
    /// header. Split because the header stays visible while the section is
    /// collapsed — a test can copy without expanding, which is the point of
    /// putting the button there rather than beside the text.
    internal static let libraryInspectorPGN     = "library.inspector.pgn"
    internal static let libraryInspectorCopyPGN = "library.inspector.pgn.copy"
    
    /// `library.inspector.pgn.disclosure` was **removed** by D45′, and a
    /// removal is as breaking as a rename (the `players.inspector.deleteItem`
    /// precedent). Unlike that one it does get a successor: the PGN section's
    /// bespoke chevron became the shared one every collapsible section now
    /// carries, so the identifier moved from a constant naming one section to
    /// the function below naming any of them.

    /// Every collapsible section's disclosure chevron, keyed by the section's
    /// own stored identity — `inspector.pgn.disclosure`,
    /// `inspector.evaluation.disclosure`, and so on.
    ///
    /// A function rather than ten constants for the `boardSquare(_:)` reason:
    /// the family is generated from a type that already exists and already
    /// guarantees uniqueness, so ten hand-written entries would be ten chances
    /// to typo a string the compiler cannot check.
    ///
    /// **It takes the raw value, not `InspectorSection`.** The rule was minted
    /// while this registry compiled into the UI test target as well as the app
    /// (F8's "separate module — keep in sync" drift, killed): that target had
    /// none of the app's types, so *every* function here took a `String` —
    /// `boardSquare` algebraic notation rather than a `Square`,
    /// `sidebarDestination` a raw value rather than a `Destination`. Typing
    /// this one to the enum compiled beautifully in the app and broke the
    /// moment the other target reached the same line. The suite is gone
    /// (D51′) and the shape is kept on purpose — the header owns that call.
    ///
    /// What is lost is a caller's inability to invent a section, and it is
    /// bought back at the call site instead: `InspectorSectionHeader`'s private
    /// `disclosure(for:)` is the only app-side caller and it holds a real
    /// `InspectorSection` when it calls. One caller, holding the type.
    ///
    /// It exists at all because the platform control doesn't: a
    /// `Section(isExpanded:)` in a sidebar `List` reveals its chevron on
    /// hover, and a section nobody can see is collapsible is a section nobody
    /// expands.
    internal static func inspectorSectionDisclosure(_ sectionRawValue: String) -> String {
        "inspector.\(sectionRawValue).disclosure"
    }
    
    /// Analysis-queue toolbar family (M-batch). `queue.status` *had* a
    /// UITest witness (asserted absent while the queue was idle — gone
    /// with the suite, D51′); the popover internals were always
    /// manual-checklist territory, since clicking Analyze in a UI test
    /// would spin live Stockfish passes.
    internal static let libraryQueueStatus  = "library.queue.status"
    internal static let libraryQueuePopover = "library.queue.popover"
    internal static let libraryQueueStopAll = "library.queue.stopAll"
    
    /// The clearable filter chip (M-prs.6) — the Library's one visible
    /// indicator that it's narrowed, and for a programmatic `.player`
    /// selection (which has no sidebar row) the *only* one.
    internal static let libraryFilterChip      = "library.filterChip"
    internal static let libraryFilterChipClear = "library.filterChip.clear"
    
    /// The Library's Export affordances, now split. The two *context menus*
    /// — list rows and cards — never coexist, since the view-mode picker
    /// guarantees only one mode is mounted, so they keep sharing
    /// `libraryExport`. The toolbar button coexists with both and carries its
    /// own, which is what made a query against the shared name ambiguous.
    internal static let libraryExportButton = "library.export.button"
    internal static let libraryExport       = "library.export"
    
    /// `gameCard.Quick Mate`, … — one per Library card, keyed by the game's
    /// display name (see `LibraryGameCardView`).
    internal static func gameCard(_ name: String) -> String {
        "gameCard.\(name)"
    }
    
    /// `gameRow.Quick Mate`, … — one per List-mode row (the White-column
    /// cell in `LibraryListView`), keyed by the game's display name.
    internal static func gameRow(_ name: String) -> String {
        "gameRow.\(name)"
    }
    
    // MARK: Cross-Destination
    
    /// The "Show in Library" context-menu item on Players rows and cards
    /// (M-prs.6; it served Rankings' too until D48′). One constant across
    /// its homes: the item is transient and no two homes ever coexist, so
    /// a family prefix would only fork future lookups. (The UITest drove
    /// it by *title* — the codebase's established menu-item pattern; the
    /// identifier is here so a future test can harden without a rename.)
    internal static let contextShowInLibrary = "context.showInLibrary"
    
    // MARK: Players
    
    internal static let playersContent          = "players.content"
    internal static let playersEmptyState       = "players.emptyState"
    internal static let playersViewModePicker   = "players.viewModePicker"
    internal static let playersTable            = "players.table"
    internal static let playersInspectorToggle  = "players.inspectorToggle"
    internal static let playersInspectorProfile = "players.inspector.profile"
    internal static let playersInspectorEmpty   = "players.inspector.empty"
    /// The multi-selection variant of the above (2 Aug 2026): 2+ players
    /// selected, the inspector names the count instead of profiling an
    /// arbitrary member.
    internal static let playersInspectorMulti   = "players.inspector.multi"

    // MARK: Player Editing (M5 — D37′; the orphan sweep is D40′)

    /// The profile header's rename pencil — D26′'s shared control with its
    /// fixed meaning, and since D52′ the header's only verb.
    ///
    /// Removals recorded here rather than done quietly, because a registry
    /// removal is as breaking as a rename: `players.inspector.deleteItem`
    /// went with the per-player Delete it named (D40′; no successor in this
    /// group — orphans have no row to select, the replacement is
    /// destination-scoped below), and `players.inspector.actionsMenu` +
    /// `players.inspector.mergeItem` went with merge itself (D52′, 4 Aug
    /// 2026 — the ellipsis menu existed for that one item).
    ///
    /// **`players.inspector.rename` is removed too (M10 / D53′).** The profile
    /// pencil went with the milestone and the identifier outlived it by a
    /// commit — kept alive only by a preview simulating a header the app no
    /// longer has, which is why the referenced-grep stayed clean while the
    /// control was gone. Successor: `getinfo.player.tag`, the field in the
    /// window that now owns the verb. Nothing is left in this group but the
    /// section identifiers below.

    /// D62′ — the ladder's ordering method. Not a sort control: it changes the
    /// rank badge, where the column headers change the row sequence.
    ///
    /// The first identifier minted after two consecutive removals left none —
    /// see the note below. Worth one line: an affordance a person points at is
    /// what this registry is for, and the run of "replaced by something that is
    /// not an affordance" turned out to be a run rather than a trend.
    internal static let playersRankingPicker = "players.rankingPicker"

    // `playersMaintenanceMenu` and `playersSweepOrphansItem` were **removed**
    // 5 Aug 2026 with D40′'s manual sweep (D60′). No successors: orphan
    // collection has no surface at all now — it happens inside the store doors
    // — and an automatic rule is the one kind of behaviour this registry
    // cannot name, because there is nothing for a person to point at.
    //
    // That makes two removals in two days with no successor control, after
    // `library.editMoves`. Both are the same shape: an affordance replaced by
    // something that is not an affordance. Worth watching rather than acting
    // on — if it keeps happening, the registry is tracking a shrinking share of
    // what the app does, and the header's bet is what would need re-reading.

    // The `player.renameSheet` family (sheet, tag field, save) was **removed**
    // with `RenamePlayerSheet` itself (M10 / D53′, 4 Aug 2026) — recorded, not
    // quiet, per the rule above. Successor: `getinfo.player.tag`.
    //
    // The tag field's doc is worth carrying across, because the reason it said
    // `tag` and not `name` is unchanged and now applies to its successor: D37′
    // — the tag is what games store and export writes, and D23′ forbids
    // deriving it back out of a display name, so the tag is what the field
    // edits. An identifier saying `name` would let a future check drift into
    // believing the field holds a display form.
    //
    // The `player.mergeSheet` family (sheet, survivor picker, confirm) was
    // **removed** with `MergePlayerSheet` (D52′, 4 Aug 2026) — same rule, one
    // evening earlier.

    /// `playerRow.Anish Giri`, … — one per list-mode row, keyed by the
    /// player's display name (the `gameRow(_:)` precedent).
    internal static func playerRow(_ name: String) -> String {
        "playerRow.\(name)"
    }
    
    /// `playerCard.Anish Giri`, … — one per card, keyed like the rows.
    internal static func playerCard(_ name: String) -> String {
        "playerCard.\(name)"
    }
    
    // `playersSortPicker` ("players.sortPicker") was **removed** 5 Aug 2026
    // with the D48′ ordering picker it named — the same class of change as the
    // `rankings.*` group below, and recorded at its old anchor for the same
    // reason: a removal is as breaking as a rename.
    //
    // **No successor, and that is the finding rather than an omission.** The
    // replacement is a `Table` sort, and a table's sort affordance is its
    // column *headers*, which SwiftUI owns and which take no identifier from
    // us. So this is the first affordance in the registry to be replaced by
    // something the registry structurally cannot name — the bet in this file's
    // header ("what a future suite would need on day one") does not cover it,
    // and a future suite would reach these headers by title or by AX role, not
    // by identifier. Worth stating here because the alternative reading of a
    // missing constant is that someone forgot.

    // The `rankings.*` group — seven constants — was **removed** with its
    // destination (D48′): removals are as breaking as renames, recorded here
    // at the group's old anchor per the `players.inspector.deleteItem`
    // precedent. `rankingRow` below is the group's one survivor, re-homed.

    /// `rankingRow.1.Liren Ding`, … — rank *and* name, so asserting a
    /// row's existence pins the ladder's computed order without geometry
    /// queries. Since D48′ it rides the merged Players table's **Rank cell**
    /// (the Player cell keeps `playerRow(name)` for the rename/merge flows —
    /// one element cannot carry both currencies).
    internal static func rankingRow(_ rank: Int, _ name: String) -> String {
        "rankingRow.\(rank).\(name)"
    }
}

// No `SeedGameName` (deleted 3 Aug 2026 with the UI test suite). It held the
// four seeded games' display names — "Quick Mate", "Ruy Lopez", "Drawn Game",
// "Black Wins" — and lived here rather than in the seed because the UI suite
// needed the same strings to build `gameCard.<name>` identifiers, and a
// hand-mirrored copy across the module boundary is the drift class F8 exists
// to kill. Both readers are gone: `UITestSeed.GameName` aliased it, and the
// suite that compared against it. Nothing in the shipping app ever named a
// game this way.
