//  TARGET MEMBERSHIP: app only since D51′ — the UITest suite that made identifiers a tested contract is gone.
//  Kept as a stated bet: what a future suite or AX audit needs on day one; discipline is the sweep's grep alone.
//  Signatures stay String-only — re-typing them buys type safety nothing checks; callers hold the real type.
//  An identifier is not surfaced to VoiceOver; that is `accessibilityLabel`, set at the control.

/// The accessibility-identifier registry. Dotted lowercase throughout. Renames break nothing at
/// compile time since D51′ — treat entries as the stable contract they were.
internal enum AccessibilityID {
    
    // MARK: Shell
    
    internal static let sidebar = "sidebar"
    
    /// `sidebar.board`, … — one per `Destination` raw value.
    internal static func sidebarDestination(_ rawValue: String) -> String {
        "sidebar.\(rawValue)"
    }
    
    /// `sidebar.tag.Checkmate`, … — keyed by tag *name*.
    internal static func sidebarTag(_ name: String) -> String {
        "sidebar.tag.\(name)"
    }
    
    internal static let sidebarTagsAdd = "sidebar.tags.add"
    
    /// Session panel (D15′); `sidebar.loaderror` family is the former `board.loaderror` — a deliberate breaking rename.
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
    /// M3 evaluation bar (D33′) — present only on the review surface over an analysed game.
    internal static let boardEvaluationBar   = "board.evaluationBar"
    
    // MARK: Evaluation Magnifier (M8, D46′)
    
    /// One identifier for the magnifier across both inspectors — one verb, one window (D46′).
    internal static let evaluationMagnifier     = "evaluation.magnifier"
    internal static let evaluationWindowGraph   = "evaluation.window.graph"
    internal static let evaluationWindowReadout = "evaluation.window.readout"
    internal static let evaluationWindowEmpty   = "evaluation.window.empty"
    
    // MARK: Analysis Data (D73′, 8 Aug 2026)
    
    /// Analysis Data glyph and window (D73′); one identifier, `evaluationMagnifier`'s reasoning.
    internal static let analysisDataButton      = "analysisData.button"
    internal static let analysisDataWindowTable = "analysisData.window.table"
    internal static let analysisDataWindowEmpty = "analysisData.window.empty"
    /// Toolbar connect control — the value once hid as a *parameter default*, which the enforcement grep cannot see.
    internal static let boardConnectButton = "board.connectButton"
    
    /// `square.e4`, … — keyed by algebraic notation (byte-identical to the old construction, pinned by `SquareTests`).
    internal static func boardSquare(_ algebraic: String) -> String {
        "square.\(algebraic)"
    }
    
    // MARK: Movetext Editor (M-lib.3, D18′)
    
    /// The movetext editor's five controls — they name the editor's *contents*, the same from
    /// whichever door hosts it (today Get Info's Move Text tab).
    internal static let movetextEditorSheet    = "movetext.editor"
    internal static let movetextEditorField    = "movetext.editor.field"
    internal static let movetextEditorStatus   = "movetext.editor.status"
    internal static let movetextEditorSave     = "movetext.editor.save"
    internal static let movetextEditorCancel   = "movetext.editor.cancel"
    
    // MARK: Get Info (M10)
    
    /// Get Info (M10): three window identifiers, not one — three subjects with three forms, and a
    /// check that found one where it expected another should fail.
    internal static let getInfoGame          = "getinfo.game"
    internal static let getInfoGameDetails   = "getinfo.game.details"
    /// Third tab (D59′); its contents keep the `movetext.editor.*` identifiers — new host, not new surface.
    internal static let getInfoGameMoveText  = "getinfo.game.movetext"
    internal static let getInfoGameFile      = "getinfo.game.file"
    
    /// Seat menus on the Details tab (D59′); raw seat string per the String-only rule.
    internal static func getInfoSeatPicker(_ seat: String) -> String {
        "getinfo.game.seatPicker.\(seat)"
    }
    internal static let getInfoLive             = "getinfo.live"
    internal static let getInfoPlayer           = "getinfo.player"
    internal static let getInfoPlayerTagField   = "getinfo.player.tag"
    internal static let getInfoEmpty            = "getinfo.empty"
    internal static let getInfoBoardMenuItem    = "getinfo.menuitem.board"
    
    /// One editable roster row on Details (D57′), keyed by lowercased tag name. Not `SevenTagRoster`:
    /// Result and Date are rows here but not text fields — a case that can never be focused.
    internal static func getInfoGameField(_ tag: String) -> String {
        "getinfo.game.field.\(tag)"
    }
    
    /// One verb reached from two row types; the destination raw value distinguishes them.
    internal static func getInfoMenuItem(_ destinationRawValue: String) -> String {
        "getinfo.menuitem.\(destinationRawValue)"
    }
    
    // MARK: Live
    
    /// HUD container names the phase — a closed set, so constants rather than a suffix helper.
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
    
    /// The live inspector's two empty states (D26′); closed set, so constants.
    internal static let liveInspectorNoGame      = "live.inspector.nogame"
    internal static let liveInspectorNoBoard     = "live.inspector.noboard"
    
    internal static let liveNewGameSheet  = "live.newgame.sheet"
    internal static let liveNewGameStart  = "live.newgame.start"
    internal static let liveNewGameNotNow = "live.newgame.notnow"
    
    /// `live.` is narrower than the truth: the sheet also serves the review inspector — shared
    /// correctly, the two callers can never coexist.
    internal static let liveEditDetailsSheet  = "live.editdetails.sheet"
    internal static let liveEditDetailsSave   = "live.editdetails.save"
    internal static let liveEditDetailsCancel = "live.editdetails.cancel"
    
    internal static let liveRecoveryPanel         = "live.recovery.panel"
    internal static let liveRecoveryCount         = "live.recovery.count"
    internal static let liveRecoveryExport        = "live.recovery.export"
    internal static let liveRecoveryRestoredFlash = "live.recovery.restoredflash"
    
    /// `live.recovery.item.e4`, … — one checklist row per square.
    internal static func liveRecoveryItem(_ algebraic: String) -> String {
        "live.recovery.item.\(algebraic)"
    }
    
    // MARK: Details Form (shared live/archive)
    
    /// Roster-form fields render under their host's prefix (`live.form.*` / `archive.form.*`);
    /// one helper per field keeps each suffix in exactly one place.
    internal static let liveFormPrefix    = "live.form"
    internal static let archiveFormPrefix = "archive.form"
    internal static func formWhite(_ prefix: String) -> String { "\(prefix).white" }
    internal static func formBlack(_ prefix: String) -> String { "\(prefix).black" }
    internal static func formEvent(_ prefix: String) -> String { "\(prefix).event" }
    internal static func formSite(_ prefix: String)  -> String { "\(prefix).site" }
    internal static func formDate(_ prefix: String)  -> String { "\(prefix).date" }
    internal static func formRound(_ prefix: String) -> String { "\(prefix).round" }
    /// Seat-picker menus (D16′) — present only when the host supplies known players.
    internal static func formWhitePicker(_ prefix: String) -> String { "\(prefix).white.picker" }
    internal static func formBlackPicker(_ prefix: String) -> String { "\(prefix).black.picker" }
    /// Seat-collision warning (D61′) — the only evidence the guard fired on these sheets: a line of
    /// text plus a disabled button.
    internal static func formSeatConflict(_ prefix: String) -> String { "\(prefix).seatConflict" }
    
    // MARK: Archive Confirmation (M5)
    
    internal static let archiveSheet = "archive.sheet"
    internal static let archiveSave  = "archive.save"
    internal static let archiveDone  = "archive.done"
    
    // MARK: DGT Connection
    
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
    internal static let settingsBoardCoordinatesToggle = "settings.boardCoordinatesToggle"
    internal static let settingsEngineDepthStepper     = "settings.engineDepthStepper"
    internal static let settingsEngineHashPicker       = "settings.engineHashPicker"
    internal static let settingsEngineThreadsStepper   = "settings.engineThreadsStepper"
    
    /// The Energy section's two gates (D66′).
    internal static let settingsPreventSleepDuringPlayToggle
    = "settings.preventSleepDuringPlayToggle"
    internal static let settingsPreventSleepDuringAnalysisToggle
    = "settings.preventSleepDuringAnalysisToggle"
    
    /// Syzygy probe controls render only once a folder is configured — conditionally present, so a
    /// future absence assertion means "not set up", never "lost".
    internal static let settingsSyzygyChoose            = "settings.syzygy.choose"
    internal static let settingsSyzygyVerify            = "settings.syzygy.verify"
    internal static let settingsSyzygyProbeDepthStepper = "settings.syzygy.probeDepthStepper"
    internal static let settingsSyzygyProbeLimitStepper = "settings.syzygy.probeLimitStepper"
    internal static let settingsSyzygy50MoveToggle      = "settings.syzygy.fiftyMoveToggle"
    internal static let settingsPieceAnimationSlider    = "settings.pieceAnimationSlider"
    
    // MARK: View Options (7 Aug 2026)
    
    // The ⌘J panel. One identifier across five hosts — it names the *command*, one verb; rows differ
    // per host, actions do not.
    internal static let showViewOptions          = "viewOptions.show"
    internal static let viewOptionsUnavailable   = "viewOptions.unavailable"
    internal static let viewOptionsSortField     = "viewOptions.sort.field"
    internal static let viewOptionsSortDirection = "viewOptions.sort.direction"
    internal static let viewOptionsIconSize      = "viewOptions.grid.iconSize"
    internal static let viewOptionsSpacing       = "viewOptions.grid.spacing"
    internal static let viewOptionsUseDefaults   = "viewOptions.grid.useDefaults"
    
    // MARK: Library
    
    internal static let libraryContent         = "library.content"
    internal static let libraryEmptyState      = "library.emptyState"
    internal static let libraryModeIcons       = "library.mode.icons"
    internal static let libraryModeList        = "library.mode.list"
    internal static let libraryModeColumns     = "library.mode.columns"
    internal static let libraryModeGallery     = "library.mode.gallery"
    internal static let libraryViewModePicker  = "library.viewModePicker"
    internal static let libraryImportButton    = "library.importButton"
    internal static let libraryGamesTable      = "library.gamesTable"
    internal static let libraryInspectorToggle = "library.inspectorToggle"
    /// Shared `InspectorEmptyState` (D26′); distinct from `libraryEmptyState`, the content area with no games.
    internal static let libraryInspectorEmpty  = "library.inspector.empty"
    /// Multi-selection variant: 2+ selected, the inspector names the count.
    internal static let libraryInspectorMulti  = "library.inspector.multi"
    
    /// Rename pencil — edits `PGN.name`, a user label outside the content hash; deliberately not part
    /// of the `board.editInfo` family.
    internal static let libraryInspectorRename = "library.inspector.rename"
    
    /// Review glyph — its own identifier despite the identical action: two controls in two headers are two controls.
    internal static let libraryInspectorReviewGlyph = "library.inspector.reviewGlyph"
    
    /// PGN text and its header copy button — split so a test can copy while the section is collapsed.
    internal static let libraryInspectorPGN     = "library.inspector.pgn"
    internal static let libraryInspectorCopyPGN = "library.inspector.pgn.copy"
    
    /// Every collapsible section's chevron, keyed by the section's stored raw value (String-only rule;
    /// `disclosure(for:)` is the one app-side caller and holds the real type).
    internal static func inspectorSectionDisclosure(_ sectionRawValue: String) -> String {
        "inspector.\(sectionRawValue).disclosure"
    }
    
    /// Analysis-queue toolbar family — queue internals are manual-checklist territory (live Stockfish).
    internal static let libraryQueueStatus  = "library.queue.status"
    
    /// The queue's own window. `analysis.`, not `library.` — the queue is app-global, and naming it
    /// after one entry point was the retired prefix's mistake.
    internal static let analysisQueueWindow  = "analysis.queue.window"
    internal static let analysisQueueSkip    = "analysis.queue.skip"
    internal static let analysisQueueStopAll = "analysis.queue.stopAll"
    /// Drained-batch acknowledgement; never coexists with `stopAll` — one identifier across two verbs lies.
    internal static let analysisQueueClear   = "analysis.queue.clear"
    
    /// The clearable filter chip — for a programmatic `.player` filter, the only indicator at all.
    internal static let libraryFilterChip      = "library.filterChip"
    internal static let libraryFilterChipClear = "library.filterChip.clear"
    
    /// Present only while some game lacks an ordinal (D40′: an affordance that cannot act is not on screen).
    internal static let libraryBackfillButton = "library.backfill.button"
    internal static let libraryExport       = "library.export"
    
    /// `gameCard.Quick Mate`, … — keyed by display name.
    internal static func gameCard(_ name: String) -> String {
        "gameCard.\(name)"
    }
    
    /// `gameRow.Quick Mate`, … — the White-column cell, keyed by display name.
    internal static func gameRow(_ name: String) -> String {
        "gameRow.\(name)"
    }
    
    // MARK: Cross-Destination
    
    /// One constant across its homes — the item is transient and no two homes ever coexist.
    internal static let contextShowInLibrary = "context.showInLibrary"
    
    // MARK: Players
    
    internal static let playersContent          = "players.content"
    internal static let playersEmptyState       = "players.emptyState"
    internal static let playersViewModePicker   = "players.viewModePicker"
    internal static let playersTable            = "players.table"
    internal static let playersInspectorToggle  = "players.inspectorToggle"
    internal static let playersInspectorProfile = "players.inspector.profile"
    internal static let playersInspectorEmpty   = "players.inspector.empty"
    /// Multi-selection variant: 2+ selected, the inspector names the count.
    internal static let playersInspectorMulti   = "players.inspector.multi"
    
    // MARK: Player Editing (M5 — D37′; the orphan sweep is D40′)
    
    /// The profile header's rename pencil — since D52′ the header's only verb.
    
    /// D62′ ranking method — not a sort control: it changes the rank badge; column headers change the row order.
    internal static let playersRankingPicker = "players.rankingPicker"
    
    /// `playerRow.Anish Giri`, … — keyed by display name.
    internal static func playerRow(_ name: String) -> String {
        "playerRow.\(name)"
    }
    
    /// `playerCard.Anish Giri`, … — one per card, keyed like the rows.
    internal static func playerCard(_ name: String) -> String {
        "playerCard.\(name)"
    }
    
    /// `rankingRow.1.Liren Ding` — rank *and* name, so one assertion pins the computed order. Rides
    /// the Rank cell; the Player cell keeps `playerRow` (one element cannot carry both currencies).
    internal static func rankingRow(_ rank: Int, _ name: String) -> String {
        "rankingRow.\(rank).\(name)"
    }
}
