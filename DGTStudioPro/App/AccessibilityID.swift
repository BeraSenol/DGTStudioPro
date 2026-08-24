/// Every accessibility identifier the app sets, in one file.
///
/// Nothing here is checked by a compiler or a test target: a rename, a removal, or a raw string
/// left in a view all build clean. The sweep's grep is the only enforcement.
///
/// - House form is dot-separated, multi-word segments camelCase (`board.flipButton`). Some legacy
///   families are compressed lowercase (`getinfo.`, `movetext.`, four under `live.`); leave them.
/// - `String` in, `String` out, deliberately: callers hold the real types.
/// - Identifiers are not spoken. That is `accessibilityLabel`, set at the control.
/// - **A match is never guaranteed unique.** Interpolated names carry user text (dots, spaces,
///   duplicates), and a constant on a shared control renders once per host. Match by prefix,
///   never split on dots.
enum AccessibilityID {
    
    // MARK: Shell
    
    static let sidebar = "sidebar"
    
    static func sidebarDestination(_ rawValue: String) -> String {
        "sidebar.\(rawValue)"
    }
    
    static func sidebarTag(_ name: String) -> String {
        "sidebar.tag.\(name)"
    }
    
    static let sidebarTagsAdd = "sidebar.tags.add"
    
    /// `sidebar.` is historical: the surface became a window at D84′ and kept its identifier.
    static let sessionPanel       = "sidebar.session"
    static let sessionWindowEmpty = "session.window.empty"
    static let showSessionWindow  = "session.show"
    // Retired `sidebar.loaderror` / `.dismiss`: the per-tab load error is an `.alert` on
    // `BoardDestination` now, reachable by button title.
    
    // MARK: Tag Editor
    
    static let tagsEditor       = "tags.editor"
    static let tagsEditorName   = "tags.editor.name"
    static let tagsEditorSave   = "tags.editor.save"
    static let tagsEditorCancel = "tags.editor.cancel"
    
    // MARK: Board
    
    static let board                = "board"
    static let boardFlipButton      = "board.flipButton"
    static let boardInspectorToggle = "board.inspectorToggle"
    static let boardConnectButton   = "board.connectButton"
    /// Absent unless the review surface has an analyzed game.
    static let boardEvaluationBar   = "board.evaluationBar"
    static let boardEvaluationBarHideToggle = "board.evaluationBar.hideToggle"
    
    /// Pinned by `SquareTests`.
    static func boardSquare(_ algebraic: String) -> String {
        "square.\(algebraic)"
    }
    
    // MARK: Evaluation Magnifier
    
    /// One identifier for the magnifier in both inspectors.
    static let evaluationMagnifier     = "evaluation.magnifier"
    static let evaluationWindowGraph   = "evaluation.window.graph"
    static let evaluationWindowReadout = "evaluation.window.readout"
    static let evaluationWindowEmpty   = "evaluation.window.empty"
    // Retired `matchupWindowEmpty`: the matchup is a Get Info subject, so a missing one falls to
    // `getInfoEmpty`.
    
    // MARK: Analysis Data
    
    static let analysisDataButton      = "analysisData.button"
    static let analysisDataWindowTable = "analysisData.window.table"
    static let analysisDataWindowEmpty = "analysisData.window.empty"
    
    // MARK: Movetext Editor
    
    /// The editor's contents keep these wherever it is hosted (today Get Info's Move Text tab).
    static let movetextEditorSheet  = "movetext.editor"
    static let movetextEditorField  = "movetext.editor.field"
    static let movetextEditorStatus = "movetext.editor.status"
    static let movetextEditorSave   = "movetext.editor.save"
    static let movetextEditorCancel = "movetext.editor.cancel"
    
    // MARK: Get Info
    
    static let getInfoGame         = "getinfo.game"
    static let getInfoGameDetails  = "getinfo.game.details"
    /// The tab; its contents keep the `movetext.editor.*` identifiers.
    static let getInfoGameMoveText = "getinfo.game.movetext"
    static let getInfoGameFile     = "getinfo.game.file"
    
    static func getInfoSeatPicker(_ seat: String) -> String {
        "getinfo.game.seatPicker.\(seat)"
    }
    
    static let getInfoLive              = "getinfo.live"
    static let getInfoPlayer            = "getinfo.player"
    static let getInfoPlayerIdentity    = "getinfo.player.identity"
    static let getInfoPlayerPerformance = "getinfo.player.performance"
    static let getInfoPlayerMatchup     = "getinfo.player.matchup"
    static let getInfoPlayerTagField    = "getinfo.player.tag"
    static let getInfoEmpty             = "getinfo.empty"
    
    /// Duplicates `getInfoMenuItem(Destination.board.rawValue)` and will not follow it if that raw
    /// value moves. One caller, `GameNavigationCommands`; its two siblings use the helper.
    static let getInfoBoardMenuItem     = "getinfo.menuitem.board"
    
    /// Tag name lowercased **and de-spaced** (`timecontrol`) — a caller convention, unenforced here.
    static func getInfoGameField(_ tag: String) -> String {
        "getinfo.game.field.\(tag)"
    }
    
    static func getInfoMenuItem(_ destinationRawValue: String) -> String {
        "getinfo.menuitem.\(destinationRawValue)"
    }
    
    // MARK: Live
    
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
    static let liveInspectorNoGame      = "live.inspector.nogame"
    static let liveInspectorNoBoard     = "live.inspector.noboard"
    
    static let liveNewGameSheet  = "live.newgame.sheet"
    static let liveNewGameStart  = "live.newgame.start"
    static let liveNewGameNotNow = "live.newgame.notnow"
    
    static let liveEditDetailsSheet  = "live.editdetails.sheet"
    static let liveEditDetailsSave   = "live.editdetails.save"
    static let liveEditDetailsCancel = "live.editdetails.cancel"
    
    static let liveRecoveryPanel         = "live.recovery.panel"
    static let liveRecoveryCount         = "live.recovery.count"
    static let liveRecoveryExport        = "live.recovery.export"
    static let liveRecoveryRestoredFlash = "live.recovery.restoredflash"
    
    static func liveRecoveryItem(_ algebraic: String) -> String {
        "live.recovery.item.\(algebraic)"
    }
    
    // MARK: Details Form (shared live/archive)
    
    /// Pass only these two prefixes. Nothing enforces it.
    static let liveFormPrefix    = "live.form"
    static let archiveFormPrefix = "archive.form"
    static func formWhite(_ prefix: String) -> String { "\(prefix).white" }
    static func formBlack(_ prefix: String) -> String { "\(prefix).black" }
    static func formEvent(_ prefix: String) -> String { "\(prefix).event" }
    static func formSite(_ prefix: String)  -> String { "\(prefix).site" }
    static func formDate(_ prefix: String)  -> String { "\(prefix).date" }
    static func formRound(_ prefix: String) -> String { "\(prefix).round" }
    /// Absent unless the host supplies known players.
    static func formWhitePicker(_ prefix: String) -> String { "\(prefix).white.picker" }
    static func formBlackPicker(_ prefix: String) -> String { "\(prefix).black.picker" }
    static func formSeatConflict(_ prefix: String) -> String { "\(prefix).seatConflict" }
    static func formSiteFormat(_ prefix: String) -> String { "\(prefix).siteFormat" }
    
    // MARK: Archive Confirmation
    
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
    
    // Flat by decision: the five tabs are a layout, and a control that changes tabs keeps its
    // identifier.
    static let settingsAutoConnectToggle      = "settings.autoConnectToggle"
    static let settingsEraseLibraryButton     = "settings.eraseLibraryButton"
    static let settingsBoardCoordinatesToggle = "settings.boardCoordinatesToggle"
    static let settingsPieceAnimationSlider   = "settings.pieceAnimationSlider"
    static let settingsEngineDepthStepper     = "settings.engineDepthStepper"
    static let settingsEngineHashPicker       = "settings.engineHashPicker"
    static let settingsEngineThreadsStepper   = "settings.engineThreadsStepper"
    
    static let settingsPreventSleepDuringPlayToggle = "settings.preventSleepDuringPlayToggle"
    static let settingsPreventSleepDuringAnalysisToggle = "settings.preventSleepDuringAnalysisToggle"
    
    /// Absent until a folder is configured, so absence means "not set up", never "lost".
    /// `settingsSyzygyVerify` rides the button labelled **Check**.
    static let settingsSyzygyChoose            = "settings.syzygy.choose"
    static let settingsSyzygyVerify            = "settings.syzygy.verify"
    static let settingsSyzygyProbeDepthStepper = "settings.syzygy.probeDepthStepper"
    static let settingsSyzygyProbeLimitStepper = "settings.syzygy.probeLimitStepper"
    /// `50Move` matches the UCI option `Syzygy50MoveRule` and `StorageKeys.syzygy50MoveRule`.
    static let settingsSyzygy50MoveToggle      = "settings.syzygy.50MoveToggle"
    
    /// Nine sound gates: eight `BoardCue`s, plus the illegal-move alert, which is not one but is
    /// gated beside them.
    static let settingsMoveSoundToggle        = "settings.moveSoundToggle"
    static let settingsCaptureSoundToggle     = "settings.captureSoundToggle"
    static let settingsCastleSoundToggle      = "settings.castleSoundToggle"
    static let settingsPromoteSoundToggle     = "settings.promoteSoundToggle"
    static let settingsCheckSoundToggle       = "settings.checkSoundToggle"
    static let settingsCheckmateSoundToggle   = "settings.checkmateSoundToggle"
    static let settingsGameStartSoundToggle   = "settings.gameStartSoundToggle"
    static let settingsGameEndSoundToggle     = "settings.gameEndSoundToggle"
    static let settingsIllegalMoveSoundToggle = "settings.illegalMoveSoundToggle"
    
    // MARK: View Options
    
    /// Rides the shared `ShowViewOptionsButton`, so in a grid mode the menu copy and the grid
    /// background copy both carry it. Only the shortcut was de-duplicated.
    static let showViewOptions            = "viewOptions.show"
    /// The state where a host offers no rows.
    static let viewOptionsUnavailable     = "viewOptions.unavailable"
    static let viewOptionsSortField       = "viewOptions.sort.field"
    static let viewOptionsSortDirection   = "viewOptions.sort.direction"
    static let viewOptionsCardInscription = "viewOptions.icon.inscription"
    static let viewOptionsIconSize        = "viewOptions.grid.iconSize"
    static let viewOptionsSpacing         = "viewOptions.grid.spacing"
    static let viewOptionsUseDefaults     = "viewOptions.grid.useDefaults"
    
    // MARK: Library
    
    static let libraryContent         = "library.content"
    /// The content area with no games — not `libraryInspectorEmpty`.
    static let libraryEmptyState      = "library.emptyState"
    static let libraryModeIcons       = "library.mode.icons"
    static let libraryModeList        = "library.mode.list"
    static let libraryModeColumns     = "library.mode.columns"
    static let libraryModeGallery     = "library.mode.gallery"
    static let libraryViewModePicker  = "library.viewModePicker"
    static let libraryInspectorToggle = "library.inspectorToggle"
    static let libraryGamesTable      = "library.gamesTable"
    
    static let libraryImportButton   = "library.importButton"
    static let libraryExport         = "library.exportButton"
    /// Absent unless some game lacks an ordinal.
    static let libraryBackfillButton = "library.backfillButton"
    
    /// The shared `InspectorEmptyState`; `…Multi` is its 2+-selected variant.
    static let libraryInspectorEmpty       = "library.inspector.empty"
    static let libraryInspectorMulti       = "library.inspector.multi"
    static let libraryInspectorReviewGlyph = "library.inspector.reviewGlyph"
    static let libraryInspectorPGN         = "library.inspector.pgn"
    static let libraryInspectorCopyPGN     = "library.inspector.pgn.copy"
    // Retired `library.inspector.rename`. Standing consequence: `PGN.name` has no editing door.
    
    static let libraryFilterChip      = "library.filterChip"
    static let libraryFilterChipClear = "library.filterChip.clear"
    
    /// The only helper interpolating somewhere other than the last segment: a raw value containing
    /// a dot breaks the shape rather than widening the tail.
    static func inspectorSectionDisclosure(_ sectionRawValue: String) -> String {
        "inspector.\(sectionRawValue).disclosure"
    }
    
    static func gameCard(_ name: String) -> String {
        "gameCard.\(name)"
    }
    
    /// Rides the White column's cell — moving that column is a contract change.
    static func gameRow(_ name: String) -> String {
        "gameRow.\(name)"
    }
    
    // MARK: Analysis Queue
    
    /// The Library toolbar's status button, hence `library.`; the window below is app-global.
    static let libraryQueueStatus   = "library.queue.status"
    static let analysisQueueWindow  = "analysis.queue.window"
    static let analysisQueueSkip    = "analysis.queue.skip"
    static let analysisQueueStopAll = "analysis.queue.stopAll"
    /// Never on screen with `stopAll`.
    static let analysisQueueClear   = "analysis.queue.clear"
    
    // MARK: Cross-Destination
    
    /// One constant across its homes; no two ever coexist.
    static let contextShowInLibrary = "context.showInLibrary"
    
    // MARK: Players
    
    static let playersContent          = "players.content"
    static let playersEmptyState       = "players.emptyState"
    static let playersViewModePicker   = "players.viewModePicker"
    static let playersTable            = "players.table"
    static let playersInspectorToggle  = "players.inspectorToggle"
    static let playersInspectorProfile = "players.inspector.profile"
    static let playersInspectorEmpty   = "players.inspector.empty"
    static let playersInspectorMulti   = "players.inspector.multi"
    
    /// Changes the rank badge, not the row order — column headers do that.
    static let playersRankingPicker = "players.rankingPicker"
    
    static func playerRow(_ name: String) -> String {
        "playerRow.\(name)"
    }
    
    static func playerCard(_ name: String) -> String {
        "playerCard.\(name)"
    }
    
    /// Rides the Rank cell, so one assertion pins the computed order; the Player cell keeps
    /// `playerRow`.
    static func rankingRow(_ rank: Int, _ name: String) -> String {
        "rankingRow.\(rank).\(name)"
    }
}
