//
//  AccessibilityID.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 16/07/2026.
//

//  TARGET MEMBERSHIP: DGTStudioPro **and** DGTStudioProUITests — and only
//  those two. The dual membership is the entire point (F8): identifiers are
//  a tested contract, and the contract only holds at compile time if both
//  sides read the same constants. (The unit-test target sees this file
//  through `@testable import DGTStudioPro`; adding it there as well would
//  duplicate the symbols.)
//
//  The rot this fixes was real: the UI suite asserted the *absence* of
//  "board.error" while the app shipped the banner as "board.loaderror" — an
//  absence assertion against a stale name passes forever while guarding
//  nothing. With both sides on constants, a rename is a compile error in the
//  UI test target instead of a silently vacuous test.
//
//  Registry of record: the F8 migrate-on-touch policy completed in M11.3 —
//  every production identifier now lives here, including the `live.*`,
//  `archive.*`, `dgt.*`, and `settings.*` families whose witness remains
//  the manual hardware checklists rather than XCUITest (live play can't be
//  XCUITest-driven without hardware injection). A raw identifier string in
//  a view is a defect from here on; `grep accessibilityIdentifier("` over
//  production sources is the enforcement.
//

/// The accessibility-identifier contract shared by the app and the UI test
/// suite. Dotted lowercase throughout; renaming any of these is a breaking
/// change to the tested contract (see the project instructions).
internal enum AccessibilityID {
    
    // MARK: Shell
    
    internal static let sidebar = "sidebar"
    
    /// `sidebar.board`, `sidebar.library`, … — one per `Destination`
    /// raw value. Takes the raw string (not the enum) so the UI test
    /// target, which can't see app types, can build the same identifiers.
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
    /// The toolbar's connect control (`DGTConnectionToolbar`). Migrated
    /// late (M-ux.3): the value lived as a *parameter default*, which the
    /// header's `accessibilityIdentifier("` enforcement grep cannot see —
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
    
    /// The review inspector's two edit affordances and the sheets they
    /// request. `board.editMoves` kept its name through the move off the
    /// toolbar into the Moves section header — same action, same destination,
    /// only the surface changed, so unlike D15′'s `board.loaderror` →
    /// `sidebar.loaderror` there was nothing to rename. `board.editInfo` is
    /// the entry `SevenTagRosterSection`'s doc predicted: the review side's
    /// own identifier rather than borrowing the live inspector's
    /// `live.inspector.editdetails`, since two buttons in two inspectors are
    /// not one button.
    ///
    /// Unlike the live families, both are reachable in a boardless UI run — a
    /// loaded PGN needs no hardware — so a future XCUITest can harden them;
    /// for now the validator and store suites are the contract.
    internal static let boardEditMovesButton = "board.editMoves"
    internal static let boardEditInfoButton  = "board.editInfo"
    internal static let movetextEditorSheet  = "movetext.editor"
    internal static let movetextEditorField  = "movetext.editor.field"
    internal static let movetextEditorStatus = "movetext.editor.status"
    internal static let movetextEditorSave   = "movetext.editor.save"
    internal static let movetextEditorCancel = "movetext.editor.cancel"
    
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
    
    internal static let dgtConnectSheet           = "dgt.connectSheet"
    internal static let dgtDeviceList             = "dgt.deviceList"
    internal static let dgtConnectingPanel        = "dgt.connectingPanel"
    internal static let dgtReconnectingPanel      = "dgt.reconnectingPanel"
    internal static let dgtConnectedPanel         = "dgt.connectedPanel"
    internal static let dgtFailedPanel            = "dgt.failedPanel"
    internal static let dgtRescanButton           = "dgt.rescanButton"
    internal static let dgtConnectButton          = "dgt.connectButton"
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
    
    /// The rename pencil, which moved onto the roster section header when the
    /// header became the game's own name. It edits `PGN.name` — a user label
    /// outside the content hash — not a tag, so it is deliberately not part
    /// of the `board.editInfo` / `live.inspector.editdetails` family even
    /// though all three are now the same glyph in the same place.
    internal static let libraryInspectorRename = "library.inspector.rename"
    
    /// The raw-PGN section: the text itself, and the copy affordance in its
    /// header. Split because the header stays visible while the section is
    /// collapsed — a test can copy without expanding, which is the point of
    /// putting the button there rather than beside the text.
    internal static let libraryInspectorPGN     = "library.inspector.pgn"
    internal static let libraryInspectorCopyPGN = "library.inspector.pgn.copy"
    
    /// The section's own disclosure control. It exists because the platform
    /// one doesn't: a `Section(isExpanded:)` in a sidebar `List` reveals its
    /// chevron on hover, and a section nobody can see is collapsible is a
    /// section nobody expands.
    internal static let libraryInspectorPGNDisclosure = "library.inspector.pgn.disclosure"
    
    /// Analysis-queue toolbar family (M-batch). `queue.status` has a
    /// UITest witness (asserted *absent* while the queue is idle); the
    /// popover internals are manual-checklist territory — clicking
    /// Analyze in a UI test would spin live Stockfish passes.
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
    
    /// The "Show in Library" context-menu item on Players/Rankings rows
    /// and cards (M-prs.6). One constant for both destinations: the item
    /// is transient and its two homes never coexist, so a family prefix
    /// would only fork future lookups. (The UITest drives it by *title* —
    /// the codebase's established menu-item pattern; the identifier is
    /// here so a future test can harden without a rename.)
    internal static let contextShowInLibrary = "context.showInLibrary"
    
    // MARK: Players
    
    internal static let playersContent          = "players.content"
    internal static let playersEmptyState       = "players.emptyState"
    internal static let playersViewModePicker   = "players.viewModePicker"
    internal static let playersTable            = "players.table"
    internal static let playersInspectorToggle  = "players.inspectorToggle"
    internal static let playersInspectorProfile = "players.inspector.profile"
    internal static let playersInspectorEmpty   = "players.inspector.empty"

    // MARK: Player Editing (M5 — D37′, D38′; the orphan sweep is D40′)

    /// The profile header's rename pencil, and the menu beside it holding the
    /// selection-scoped operation that isn't a rename. Separate identifiers
    /// because they are separate affordances: the pencil is D26′'s shared
    /// control with its fixed meaning, and folding "merge" into it would widen
    /// a named affordance into a generic one.
    ///
    /// `players.inspector.deleteItem` was **removed** with the per-player
    /// Delete it named (D40′). A registry removal is a breaking
    /// accessibility-contract change, so it is recorded here rather than done
    /// quietly — and it gets no successor in this group, because an orphan has
    /// no row to select and the replacement is destination-scoped (below).
    internal static let playersRenameButton   = "players.inspector.rename"
    internal static let playersActionsMenu    = "players.inspector.actionsMenu"
    internal static let playersMergeMenuItem  = "players.inspector.mergeItem"

    /// The destination's maintenance menu and its one item (D40′), on the
    /// toolbar rather than in the inspector: orphaned players contribute to no
    /// `GameRecord`, so they appear in no view mode and can never be selected —
    /// which is the finding the decision came from. A toolbar affordance is the
    /// only kind that can reach them.
    internal static let playersMaintenanceMenu  = "players.maintenanceMenu"
    internal static let playersSweepOrphansItem = "players.maintenanceMenu.deleteUnused"

    internal static let playerRenameSheet     = "player.renameSheet"
    /// The **tag-form** field — "Senol, Bera". D37′: the tag is what games
    /// store and export writes, and D23′ forbids deriving it back out of a
    /// display name, so the tag is what the sheet edits. The identifier says
    /// `tag` rather than `name` so a test asserting on it can't drift into
    /// believing this field holds a display name.
    internal static let playerRenameTagField  = "player.renameSheet.tag"
    internal static let playerRenameSave      = "player.renameSheet.save"

    internal static let playerMergeSheet      = "player.mergeSheet"
    internal static let playerMergePicker     = "player.mergeSheet.survivor"
    internal static let playerMergeConfirm    = "player.mergeSheet.merge"
    
    /// `playerRow.Anish Giri`, … — one per list-mode row, keyed by the
    /// player's display name (the `gameRow(_:)` precedent).
    internal static func playerRow(_ name: String) -> String {
        "playerRow.\(name)"
    }
    
    /// `playerCard.Anish Giri`, … — one per card, keyed like the rows.
    internal static func playerCard(_ name: String) -> String {
        "playerCard.\(name)"
    }
    
    // MARK: Rankings
    
    internal static let rankingsContent          = "rankings.content"
    internal static let rankingsEmptyState       = "rankings.emptyState"
    internal static let rankingsViewModePicker   = "rankings.viewModePicker"
    internal static let rankingsTable            = "rankings.table"
    internal static let rankingsInspectorToggle  = "rankings.inspectorToggle"
    internal static let rankingsInspectorProfile = "rankings.inspector.profile"
    internal static let rankingsInspectorEmpty   = "rankings.inspector.empty"
    
    /// `rankingRow.1.Liren Ding`, … — rank *and* name, so asserting a
    /// row's existence pins the ladder's computed order without geometry
    /// queries.
    internal static func rankingRow(_ rank: Int, _ name: String) -> String {
        "rankingRow.\(rank).\(name)"
    }
}

/// The seeded Library's game display names, shared for the same reason as
/// the identifiers above: the UI suite previously kept a hand-mirrored copy
/// ("separate module — keep in sync"), which is the same drift class F8
/// exists to kill. `UITestSeed.GameName` aliases these so the seeding code
/// reads unchanged.
internal enum SeedGameName {
    internal static let quickMate = "Quick Mate"
    internal static let ruyLopez  = "Ruy Lopez"
    internal static let drawnGame = "Drawn Game"
    internal static let blackWins = "Black Wins"
}
