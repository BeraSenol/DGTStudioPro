// TARGET MEMBERSHIP: app only - the UITest suite that made identifiers a tested contract is gone.
//  Kept as a stated bet: what a future suite or AX audit needs on day one; discipline is the sweep's grep alone.
//  Signatures stay String-only - re-typing them buys type safety nothing checks; callers hold the real type.
//  An identifier is not surfaced to VoiceOver; that is `accessibilityLabel`, set at the control.

/// The accessibility-identifier registry. Dotted lowercase throughout. Renames break nothing at
/// compile time - treat entries as the stable contract they were.
enum AccessibilityID {
    
    // MARK: Shell
    
    static let sidebar = "sidebar"
    
    /// `sidebar.board`, … - one per `Destination` raw value.
    static func sidebarDestination(_ rawValue: String) -> String {
        "sidebar.\(rawValue)"
    }
    
    /// `sidebar.tag.Checkmate`, … - keyed by tag *name*.
    static func sidebarTag(_ name: String) -> String {
        "sidebar.tag.\(name)"
    }
    
    static let sidebarTagsAdd = "sidebar.tags.add"
    
    /// Session panel; `sidebar.loaderror` family is the former `board.loaderror` - a deliberate breaking rename.
    static let sessionPanel            = "sidebar.session"
    static let sidebarLoadError        = "sidebar.loaderror"
    static let sidebarLoadErrorDismiss = "sidebar.loaderror.dismiss"
    
    // MARK: Tag Editor (M-prs.5)
    
    static let tagsEditor       = "tags.editor"
    static let tagsEditorName   = "tags.editor.name"
    static let tagsEditorSave   = "tags.editor.save"
    static let tagsEditorCancel = "tags.editor.cancel"
    
    // MARK: Board
    
    static let board                = "board"
    static let boardFlipButton      = "board.flipButton"
    static let boardInspectorToggle = "board.inspectorToggle"
    /// M3 evaluation bar - present only on the review surface over an analysed game.
    static let boardEvaluationBar   = "board.evaluationBar"
    
    // MARK: Evaluation Magnifier (M8)
    
    /// One identifier for the magnifier across both inspectors - one verb, one window.
    static let evaluationMagnifier     = "evaluation.magnifier"
    static let evaluationWindowGraph   = "evaluation.window.graph"
    static let evaluationWindowReadout = "evaluation.window.readout"
    static let evaluationWindowEmpty   = "evaluation.window.empty"
    static let matchupWindowEmpty      = "matchup.window.empty"
    static let boardEvaluationBarHideToggle = "board.evaluationBar.hideToggle"
    
    // MARK: Analysis Data (8 Aug 2026)
    
    /// Analysis Data glyph and window; one identifier, `evaluationMagnifier`'s reasoning.
    static let analysisDataButton      = "analysisData.button"
    static let analysisDataWindowTable = "analysisData.window.table"
    static let analysisDataWindowEmpty = "analysisData.window.empty"
    /// Toolbar connect control - the value once hid as a *parameter default*, which the enforcement grep cannot see.
    static let boardConnectButton = "board.connectButton"
    
    /// `square.e4`, … - keyed by algebraic notation (byte-identical to the old construction, pinned by `SquareTests`).
    static func boardSquare(_ algebraic: String) -> String {
        "square.\(algebraic)"
    }
    
    // MARK: Movetext Editor (M-lib.3)
    
    /// The movetext editor's five controls - they name the editor's *contents*, the same from
    /// whichever door hosts it (today Get Info's Move Text tab).
    static let movetextEditorSheet    = "movetext.editor"
    static let movetextEditorField    = "movetext.editor.field"
    static let movetextEditorStatus   = "movetext.editor.status"
    static let movetextEditorSave     = "movetext.editor.save"
    static let movetextEditorCancel   = "movetext.editor.cancel"
    
    // MARK: Get Info (M10)
    
    /// Get Info (M10): three window identifiers, not one - three subjects with three forms, and a
    /// check that found one where it expected another should fail.
    static let getInfoGame          = "getinfo.game"
    static let getInfoGameDetails   = "getinfo.game.details"
    /// Third tab; its contents keep the `movetext.editor.*` identifiers - new host, not new surface.
    static let getInfoGameMoveText  = "getinfo.game.movetext"
    static let getInfoGameFile      = "getinfo.game.file"
    
    /// Seat menus on the Details tab; raw seat string per the String-only rule.
    static func getInfoSeatPicker(_ seat: String) -> String {
        "getinfo.game.seatPicker.\(seat)"
    }
    static let getInfoLive             = "getinfo.live"
    static let getInfoPlayer           = "getinfo.player"
    static let getInfoPlayerTagField   = "getinfo.player.tag"
    static let getInfoEmpty            = "getinfo.empty"
    static let getInfoBoardMenuItem    = "getinfo.menuitem.board"
    
    /// One editable roster row on Details, keyed by lowercased tag name. Not `SevenTagRoster`:
    /// Result and Date are rows here but not text fields - a case that can never be focused.
    static func getInfoGameField(_ tag: String) -> String {
        "getinfo.game.field.\(tag)"
    }
    
    /// One verb reached from two row types; the destination raw value distinguishes them.
    static func getInfoMenuItem(_ destinationRawValue: String) -> String {
        "getinfo.menuitem.\(destinationRawValue)"
    }
    
    // MARK: Live
    
    /// HUD container names the phase - a closed set, so constants rather than a suffix helper.
    static let liveHUDReconnecting  = "live.hud.reconnecting"
    static let liveHUDIdle          = "live.hud.idle"
    static let liveHUDAwaitingSetup = "live.hud.awaitingsetup"
    static let liveHUDPlaying       = "live.hud.playing"
    static let liveHUDCorrection    = "live.hud.correction"
    static let liveHUDRecovering    = "live.hud.recovering"
    static let liveHUDFinished      = "live.hud.finished"
    static let liveHUDArchiveFailed = "live.hud.archivefailed"
    static let liveHUDNewGame       = "live.hud.newgame"
    static let liveHUDRetryArchive  = "live.hud.retryarchive"
    
    static let liveInspector            = "live.inspector"
    static let liveInspectorEditDetails = "live.inspector.editdetails"
    static let liveInspectorResign      = "live.inspector.resign"
    static let liveInspectorDraw        = "live.inspector.draw"
    static let liveInspectorDiscard     = "live.inspector.discard"
    
    /// The live inspector's two empty states; closed set, so constants.
    static let liveInspectorNoGame      = "live.inspector.nogame"
    static let liveInspectorNoBoard     = "live.inspector.noboard"
    
    static let liveNewGameSheet  = "live.newgame.sheet"
    static let liveNewGameStart  = "live.newgame.start"
    static let liveNewGameNotNow = "live.newgame.notnow"
    
    /// `live.` is exactly the truth since Get Info retired the review inspector's Edit Info: the live
    /// inspector is the sheet's one caller. (This doc said "narrower than the truth - also serves
    /// the review inspector" for a week after that stopped being so; corrected 16 Aug 2026.)
    static let liveEditDetailsSheet  = "live.editdetails.sheet"
    static let liveEditDetailsSave   = "live.editdetails.save"
    static let liveEditDetailsCancel = "live.editdetails.cancel"
    
    static let liveRecoveryPanel         = "live.recovery.panel"
    static let liveRecoveryCount         = "live.recovery.count"
    static let liveRecoveryExport        = "live.recovery.export"
    static let liveRecoveryRestoredFlash = "live.recovery.restoredflash"
    
    /// `live.recovery.item.e4`, … - one checklist row per square.
    static func liveRecoveryItem(_ algebraic: String) -> String {
        "live.recovery.item.\(algebraic)"
    }
    
    // MARK: Details Form (shared live/archive)
    
    /// Roster-form fields render under their host's prefix (`live.form.*` / `archive.form.*`);
    /// one helper per field keeps each suffix in exactly one place.
    static let liveFormPrefix    = "live.form"
    static let archiveFormPrefix = "archive.form"
    static func formWhite(_ prefix: String) -> String { "\(prefix).white" }
    static func formBlack(_ prefix: String) -> String { "\(prefix).black" }
    static func formEvent(_ prefix: String) -> String { "\(prefix).event" }
    static func formSite(_ prefix: String)  -> String { "\(prefix).site" }
    static func formDate(_ prefix: String)  -> String { "\(prefix).date" }
    static func formRound(_ prefix: String) -> String { "\(prefix).round" }
    /// Seat-picker menus - present only when the host supplies known players.
    static func formWhitePicker(_ prefix: String) -> String { "\(prefix).white.picker" }
    static func formBlackPicker(_ prefix: String) -> String { "\(prefix).black.picker" }
    /// Seat-collision warning - the only evidence the guard fired on these sheets: a line of
    /// text plus a disabled button.
    static func formSeatConflict(_ prefix: String) -> String { "\(prefix).seatConflict" }
    /// Site-format warning ("City, Region CCC", 16 Aug 2026) - same shape as the seat guard.
    static func formSiteFormat(_ prefix: String) -> String { "\(prefix).siteFormat" }
    
    // MARK: Archive Confirmation (M5)
    
    static let archiveSheet = "archive.sheet"
    static let archiveSave  = "archive.save"
    static let archiveDone  = "archive.done"
    
    // MARK: DGT Connection
    
    static let dgtConnectSheet           = "dgt.connectSheet"
    static let dgtConnectingPanel        = "dgt.connectingPanel"
    static let dgtReconnectingPanel      = "dgt.reconnectingPanel"
    static let dgtConnectedPanel         = "dgt.connectedPanel"
    static let dgtFailedPanel            = "dgt.failedPanel"
    static let dgtNotFoundPanel          = "dgt.notFoundPanel"
    static let dgtCancelButton           = "dgt.cancelButton"
    static let dgtStopReconnectingButton = "dgt.stopReconnectingButton"
    static let dgtDisconnectButton       = "dgt.disconnectButton"
    static let dgtRetryButton            = "dgt.retryButton"
    
    // MARK: Settings
    
    static let settingsAutoConnectToggle      = "settings.autoConnectToggle"
    static let settingsEraseLibraryButton     = "settings.eraseLibraryButton"
    static let settingsIllegalMoveSoundToggle = "settings.illegalMoveSoundToggle"
    static let settingsBoardCoordinatesToggle = "settings.boardCoordinatesToggle"
    static let settingsEngineDepthStepper     = "settings.engineDepthStepper"
    static let settingsEngineHashPicker       = "settings.engineHashPicker"
    static let settingsEngineThreadsStepper   = "settings.engineThreadsStepper"
    
    /// The Energy section's two gates.
    static let settingsPreventSleepDuringPlayToggle
    = "settings.preventSleepDuringPlayToggle"
    static let settingsPreventSleepDuringAnalysisToggle
    = "settings.preventSleepDuringAnalysisToggle"
    
    /// Syzygy probe controls render only once a folder is configured - conditionally present, so a
    /// future absence assertion means "not set up", never "lost".
    static let settingsSyzygyChoose            = "settings.syzygy.choose"
    static let settingsSyzygyVerify            = "settings.syzygy.verify"
    static let settingsSyzygyProbeDepthStepper = "settings.syzygy.probeDepthStepper"
    static let settingsSyzygyProbeLimitStepper = "settings.syzygy.probeLimitStepper"
    static let settingsSyzygy50MoveToggle      = "settings.syzygy.fiftyMoveToggle"
    static let settingsPieceAnimationSlider    = "settings.pieceAnimationSlider"

    /// The four board cues. One identifier per toggle rather than one for the section - a
    /// section is not a control, and a cue that stops firing is diagnosed by naming *which* toggle.
    // `settingsBoardSoundSetPicker` is gone with the picker itself - the app ships one set of
    // sounds and offers only which cues are on.
    static let settingsMoveSoundToggle      = "settings.moveSoundToggle"
    static let settingsCaptureSoundToggle   = "settings.captureSoundToggle"
    static let settingsCastleSoundToggle    = "settings.castleSoundToggle"
    static let settingsPromoteSoundToggle   = "settings.promoteSoundToggle"
    static let settingsCheckSoundToggle     = "settings.checkSoundToggle"
    static let settingsCheckmateSoundToggle = "settings.checkmateSoundToggle"
    static let settingsGameStartSoundToggle = "settings.gameStartSoundToggle"
    static let settingsGameEndSoundToggle   = "settings.gameEndSoundToggle"
    
    // MARK: View Options (7 Aug 2026)
    
    // The ⌘J panel. One identifier across five hosts - it names the *command*, one verb; rows differ
    // per host, actions do not.
    static let showViewOptions          = "viewOptions.show"
    static let viewOptionsUnavailable   = "viewOptions.unavailable"
    static let viewOptionsSortField     = "viewOptions.sort.field"
    static let viewOptionsSortDirection = "viewOptions.sort.direction"
    static let viewOptionsIconSize      = "viewOptions.grid.iconSize"
    static let viewOptionsSpacing       = "viewOptions.grid.spacing"
    static let viewOptionsUseDefaults   = "viewOptions.grid.useDefaults"
    
    // MARK: Library
    
    static let libraryContent         = "library.content"
    static let libraryEmptyState      = "library.emptyState"
    static let libraryModeIcons       = "library.mode.icons"
    static let libraryModeList        = "library.mode.list"
    static let libraryModeColumns     = "library.mode.columns"
    static let libraryModeGallery     = "library.mode.gallery"
    static let libraryViewModePicker  = "library.viewModePicker"
    static let libraryImportButton    = "library.importButton"
    static let libraryGamesTable      = "library.gamesTable"
    static let libraryInspectorToggle = "library.inspectorToggle"
    /// Shared `InspectorEmptyState`; distinct from `libraryEmptyState`, the content area with no games.
    static let libraryInspectorEmpty  = "library.inspector.empty"
    /// Multi-selection variant: 2+ selected, the inspector names the count.
    static let libraryInspectorMulti  = "library.inspector.multi"
    
    // `library.inspector.rename` removed 16 Aug 2026. It named the roster header's Rename pencil
    // (editing `PGN.name`), an affordance the inspector no longer renders; its last reference was
    // a preview simulating the retired header - the `playersRenameButton` shape again, a preview
    // reading as evidence. Note recorded with the removal: `PGN.name` currently has **no** editing
    // door anywhere - Get Info's Details tab holds the nine exported tags and name is not one.

    /// Review glyph - its own identifier despite the identical action: two controls in two headers are two controls.
    static let libraryInspectorReviewGlyph = "library.inspector.reviewGlyph"
    
    /// PGN text and its header copy button - split so a test can copy while the section is collapsed.
    static let libraryInspectorPGN     = "library.inspector.pgn"
    static let libraryInspectorCopyPGN = "library.inspector.pgn.copy"
    
    /// Every collapsible section's chevron, keyed by the section's stored raw value (String-only rule;
    /// `disclosure(for:)` is the one app-side caller and holds the real type).
    static func inspectorSectionDisclosure(_ sectionRawValue: String) -> String {
        "inspector.\(sectionRawValue).disclosure"
    }
    
    /// Analysis-queue toolbar family - queue internals are manual-checklist territory (live Stockfish).
    static let libraryQueueStatus  = "library.queue.status"
    
    /// The queue's own window. `analysis.`, not `library.` - the queue is app-global, and naming it
    /// after one entry point was the retired prefix's mistake.
    static let analysisQueueWindow  = "analysis.queue.window"
    static let analysisQueueSkip    = "analysis.queue.skip"
    static let analysisQueueStopAll = "analysis.queue.stopAll"
    /// Drained-batch acknowledgement; never coexists with `stopAll` - one identifier across two verbs lies.
    static let analysisQueueClear   = "analysis.queue.clear"
    
    /// The clearable filter chip - for a programmatic `.player` filter, the only indicator at all.
    static let libraryFilterChip      = "library.filterChip"
    static let libraryFilterChipClear = "library.filterChip.clear"
    
    /// Present only while some game lacks an ordinal (an affordance that cannot act is not on screen).
    static let libraryBackfillButton = "library.backfill.button"
    static let libraryExport       = "library.export"
    
    /// `gameCard.Quick Mate`, … - keyed by display name.
    static func gameCard(_ name: String) -> String {
        "gameCard.\(name)"
    }
    
    /// `gameRow.Quick Mate`, … - the White-column cell, keyed by display name.
    static func gameRow(_ name: String) -> String {
        "gameRow.\(name)"
    }
    
    // MARK: Cross-Destination
    
    /// One constant across its homes - the item is transient and no two homes ever coexist.
    static let contextShowInLibrary = "context.showInLibrary"
    
    // MARK: Players
    
    static let playersContent          = "players.content"
    static let playersEmptyState       = "players.emptyState"
    static let playersViewModePicker   = "players.viewModePicker"
    static let playersTable            = "players.table"
    static let playersInspectorToggle  = "players.inspectorToggle"
    static let playersInspectorProfile = "players.inspector.profile"
    static let playersInspectorEmpty   = "players.inspector.empty"
    /// Multi-selection variant: 2+ selected, the inspector names the count.
    static let playersInspectorMulti   = "players.inspector.multi"
    
    // MARK: Player Editing

    // (An orphaned doc line - "The profile header's rename pencil - the header's only verb." -
    // stood here until 16 Aug 2026. Its constant left when rename moved to Get Info; successor `getinfo.player.tag`.)

    /// The ranking method - not a sort control: it changes the rank badge; column headers change the row order.
    static let playersRankingPicker = "players.rankingPicker"
    
    /// `playerRow.Anish Giri`, … - keyed by display name.
    static func playerRow(_ name: String) -> String {
        "playerRow.\(name)"
    }
    
    /// `playerCard.Anish Giri`, … - one per card, keyed like the rows.
    static func playerCard(_ name: String) -> String {
        "playerCard.\(name)"
    }
    
    /// `rankingRow.1.Liren Ding` - rank *and* name, so one assertion pins the computed order. Rides
    /// the Rank cell; the Player cell keeps `playerRow` (one element cannot carry both currencies).
    static func rankingRow(_ rank: Int, _ name: String) -> String {
        "rankingRow.\(rank).\(name)"
    }
}
