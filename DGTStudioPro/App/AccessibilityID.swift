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
//  Registry of record: identifiers migrate here from string literals as
//  their files are touched. The `live.*` HUD/inspector and `archive.form.*`
//  families are still literals at their call sites (they're exercised by the
//  manual hardware checklists, not XCUITest — live play can't be
//  XCUITest-driven without hardware injection); they migrate on next touch
//  of those files.
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
    
    /// `sidebar.tag.checkmate`, … — one per `SmartTag` raw value.
    internal static func sidebarTag(_ rawValue: String) -> String {
        "sidebar.tag.\(rawValue)"
    }
    
    // MARK: Board
    
    internal static let board = "board"
    internal static let boardFlipButton = "board.flipButton"
    internal static let boardInspectorToggle = "board.inspectorToggle"
    internal static let boardLoadError = "board.loaderror"
    internal static let boardLoadErrorDismiss = "board.loaderror.dismiss"
    
    // MARK: Live
    
    internal static let liveRecoveryRestoredFlash = "live.recovery.restoredflash"
    
    // MARK: Library
    
    internal static let libraryContent = "library.content"
    internal static let libraryEmptyState = "library.emptyState"
    internal static let libraryModeIcons = "library.mode.icons"
    internal static let libraryModeList = "library.mode.list"
    internal static let libraryModeColumns = "library.mode.columns"
    internal static let libraryModeGallery = "library.mode.gallery"
    internal static let libraryViewModePicker = "library.viewModePicker"
    internal static let libraryImportButton = "library.importButton"
    internal static let libraryAnalyzeButton = "library.analyzeButton"
    internal static let libraryDeleteButton = "library.deleteButton"
    internal static let libraryGamesTable = "library.gamesTable"
    internal static let libraryInspectorToggle = "library.inspectorToggle"
    
    /// Analysis-queue toolbar family (M-batch). `queue.status` has a
    /// UITest witness (asserted *absent* while the queue is idle); the
    /// popover internals are manual-checklist territory — clicking
    /// Analyze in a UI test would spin live Stockfish passes.
    internal static let libraryQueueStatus = "library.queue.status"
    internal static let libraryQueuePopover = "library.queue.popover"
    internal static let libraryQueueStopAll = "library.queue.stopAll"
    
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
    
    // MARK: Players
    
    internal static let playersContent = "players.content"
    internal static let playersEmptyState = "players.emptyState"
    internal static let playersViewModePicker = "players.viewModePicker"
    internal static let playersTable = "players.table"
    internal static let playersInspectorToggle = "players.inspectorToggle"
    internal static let playersInspectorProfile = "players.inspector.profile"
    
    /// `playerRow.Anish Giri`, … — one per list-mode row, keyed by the
    /// player's display name (the `gameRow(_:)` precedent).
    internal static func playerRow(_ name: String) -> String {
        "playerRow.\(name)"
    }
    
    /// `playerCard.Anish Giri`, … — one per card, keyed like the rows.
    internal static func playerCard(_ name: String) -> String {
        "playerCard.\(name)"
    }
    
    // MARK: v1 Placeholders
    
    internal static let rankingsContent = "rankings.content"
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
