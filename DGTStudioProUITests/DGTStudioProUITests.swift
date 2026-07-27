//
//  DGTStudioProUITests.swift
//  DGTStudioProUITests
//
//  Created by Supreme Leader on 24/03/2026.
//

//  Broad smoke suite. Each test launches the app with `-uiTestSeed`, so
//  the Library is populated from `UITestSeed` (in-memory; the real
//  library is never touched). Breadth over depth.
//
//  Requires `.defaultLaunchBehavior(.presented)` on DGTStudioProApp.
//  `launch()` also opens a window via File ▸ New Window as a fallback,
//  since a value-based WindowGroup may still present no window on a clean,
//  in-memory test launch.
//
//  Identifiers and seed-game names come from `AccessibilityID.swift`, a
//  file compiled into BOTH this target and the app target (F8): a rename
//  on either side is now a compile error here instead of a silently
//  vacuous assertion. (The suite once asserted the absence of
//  "board.error" while the app shipped "board.loaderror" — green forever,
//  guarding nothing.)
//
//  macOS specific: a `.segmented` Picker of `Label(_:systemImage:)`
//  renders icon-only; its segments are radioButtons keyed by SF Symbol
//  name, and report selection via the AXValue (0/1) attribute — NOT the
//  AXSelected flag that `.isSelected` reads. So selection is verified via
//  `value == 1` (see `assertPicked`).
//

import XCTest

final class DGTStudioProUITests: XCTestCase {
    
    private var app: XCUIApplication!
    
    // View-mode segment handles: the SF Symbol name each mode uses. (These
    // aren't accessibility identifiers — macOS renders the segments as
    // radio buttons keyed by symbol name, see the header — so they stay
    // local rather than joining AccessibilityID.)
    private enum ModeSymbol {
        static let icons   = "square.grid.2x2"
        static let list    = "list.bullet"
        static let columns = "rectangle.split.3x1"
        static let gallery = "squares.below.rectangle"
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: Launch
    
    private func launch() {
        app.launchArguments = ["-uiTestSeed", "YES"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10),
                      "App should reach the foreground")
        
        // The window should auto-present thanks to
        // `.defaultLaunchBehavior(.presented)`.
        if app.windows.firstMatch.waitForExistence(timeout: 8) { return }
        
        // Fallback: drive File ▸ New Window if no window auto-presented.
        app.activate()
        let fileMenu = app.menuBars.menuBarItems["File"]
        if fileMenu.waitForExistence(timeout: 3) {
            fileMenu.click()
            let newWindow = app.menuBars.menuItems["New DGT Studio Pro Window"]
            if newWindow.waitForExistence(timeout: 3) {
                newWindow.click()
            } else {
                app.typeKey(.escape, modifierFlags: [])
            }
        }
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "A window should be present at launch")
    }
    
    // MARK: Helpers
    
    /// Type-agnostic lookup by accessibility identifier.
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
    
    @discardableResult
    private func waitFor(_ element: XCUIElement, _ timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }
    
    private func segment(_ symbol: String) -> XCUIElement {
        app.radioButtons[symbol]
    }
    
    /// A segmented-control segment is selected when its AXValue is 1.
    /// (`.isSelected` reads AXSelected, which these segments never set.)
    private func isPicked(_ e: XCUIElement) -> Bool {
        switch e.value {
        case let n as NSNumber: return n.intValue == 1
        case let n as Int:      return n == 1
        case let s as String:   return s == "1"
        case let b as Bool:     return b
        default:                return false
        }
    }
    
    /// Polls the segment's value briefly to absorb update latency, then
    /// fails if it never reaches the selected state.
    private func assertPicked(_ e: XCUIElement, _ message: String,
                              timeout: TimeInterval = 3,
                              file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isPicked(e) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail(message, file: file, line: line)
    }
    
    // MARK: Tests
    
    func test_launch_showsSidebarAndLibrary() {
        launch()
        XCTAssertTrue(waitFor(element(AccessibilityID.sidebar)),
                      "Sidebar should be present at launch")
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)),
                      "Library should be the default destination")
    }
    
    func test_sidebar_navigatesToEachDestination() {
        launch()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)))
        
        element(AccessibilityID.sidebarDestination("board")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.board)),
                      "Board should render the live mirror (no game loaded)")
        
        element(AccessibilityID.sidebarDestination("players")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.playersContent)),
                      "Players destination should appear")
        
        element(AccessibilityID.sidebarDestination("rankings")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.rankingsContent)),
                      "Rankings destination should appear")
        
        element(AccessibilityID.sidebarDestination("library")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)),
                      "Library should reappear when reselected")
    }
    
    /// The centerpiece: cycle the picker through all four modes, keyed by
    /// SF Symbol name, verifying each becomes the selected segment.
    func test_viewModes_switchAcrossAllFour() {
        launch()
        
        let icons   = segment(ModeSymbol.icons)
        let list    = segment(ModeSymbol.list)
        let columns = segment(ModeSymbol.columns)
        let gallery = segment(ModeSymbol.gallery)
        
        XCTAssertTrue(list.waitForExistence(timeout: 5),
                      "View-mode picker should be present")
        
        icons.click()
        assertPicked(icons,   "Icons segment should be selected")
        
        columns.click()
        assertPicked(columns, "Columns segment should be selected")
        
        gallery.click()
        assertPicked(gallery, "Gallery segment should be selected")
        
        list.click()
        assertPicked(list,    "List segment should be selected")
    }
    
    func test_sidebar_tagFilterRendersLibrary() {
        launch()
        // Name-keyed since M-prs.5 (the enum's raw values are gone).
        element(AccessibilityID.sidebarTag("Checkmate")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)),
                      "Tag-filtered Library should render its content area")
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryFilterChip)),
                      "The filter chip should announce the active tag (M-prs.6)")
    }
    // MARK: Players (M-prs.3)
    
    /// The seed's raw tags surface as resolved display identities — the
    /// end-to-end witness that "Lopez, Ruy" became the player "Ruy Lopez"
    /// through resolver + index + view.
    func test_players_listShowsResolvedSeedPlayers() {
        launch()
        element(AccessibilityID.sidebarDestination("players")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.playersContent)),
                      "Players destination should appear")
        
        XCTAssertTrue(waitFor(element(AccessibilityID.playerRow("Ruy Lopez"))),
                      "Seed tag 'Lopez, Ruy' should surface as the player 'Ruy Lopez'")
        XCTAssertTrue(element(AccessibilityID.playerRow("Anish Giri")).exists)
        XCTAssertTrue(element(AccessibilityID.playerRow("Liren Ding")).exists)
    }
    
    /// The parity promise: the same four modes cycle on Players, via the
    /// same symbol-keyed segments (only one destination's toolbar exists
    /// at a time, so the shared handles resolve to Players' picker here).
    func test_players_viewModes_switchAcrossAllFour() {
        launch()
        element(AccessibilityID.sidebarDestination("players")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.playersContent)))
        
        let icons   = segment(ModeSymbol.icons)
        let list    = segment(ModeSymbol.list)
        let columns = segment(ModeSymbol.columns)
        let gallery = segment(ModeSymbol.gallery)
        
        XCTAssertTrue(list.waitForExistence(timeout: 5),
                      "Players view-mode picker should be present")
        
        icons.click()
        assertPicked(icons,   "Icons segment should be selected")
        
        columns.click()
        assertPicked(columns, "Columns segment should be selected")
        
        gallery.click()
        assertPicked(gallery, "Gallery segment should be selected")
        
        list.click()
        assertPicked(list,    "List segment should be selected")
    }
    
    /// Select a row, open the inspector, and the profile section loads.
    func test_players_selection_populatesInspectorProfile() {
        launch()
        element(AccessibilityID.sidebarDestination("players")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.playerRow("Anish Giri"))))
        
        element(AccessibilityID.playerRow("Anish Giri")).click()
        element(AccessibilityID.playersInspectorToggle).click()
        
        XCTAssertTrue(waitFor(element(AccessibilityID.playersInspectorProfile)),
                      "Inspector should show the selected player's profile")
    }
    
    // MARK: Rankings (M-prs.4)
    
    /// Pins the seeded ladder end to end: two 1-win players (both 100%,
    /// so the key tiebreak decides 1 vs 2), then the zero-win group led
    /// alphabetically. Seeds are undated, so chronology and the ladder
    /// derive purely from seed insertion — deterministic by construction.
    func test_rankings_ladderOrderMatchesComparator() {
        launch()
        element(AccessibilityID.sidebarDestination("rankings")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.rankingsContent)),
                      "Rankings destination should appear")
        
        XCTAssertTrue(waitFor(element(AccessibilityID.rankingRow(1, "Liren Ding"))),
                      "Key tiebreak: 'liren ding' < 'player black' at equal wins and win rate")
        XCTAssertTrue(element(AccessibilityID.rankingRow(2, "Player Black")).exists)
        XCTAssertTrue(element(AccessibilityID.rankingRow(3, "Alireza Firouzja")).exists,
                      "Zero-win group starts at rank 3, key-ascending")
    }
    
    /// The parity promise, third destination: same four modes, same
    /// symbol-keyed segments.
    func test_rankings_viewModes_switchAcrossAllFour() {
        launch()
        element(AccessibilityID.sidebarDestination("rankings")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.rankingsContent)))
        
        let icons   = segment(ModeSymbol.icons)
        let list    = segment(ModeSymbol.list)
        let columns = segment(ModeSymbol.columns)
        let gallery = segment(ModeSymbol.gallery)
        
        XCTAssertTrue(list.waitForExistence(timeout: 5),
                      "Rankings view-mode picker should be present")
        
        icons.click()
        assertPicked(icons,   "Icons segment should be selected")
        
        columns.click()
        assertPicked(columns, "Columns segment should be selected")
        
        gallery.click()
        assertPicked(gallery, "Gallery segment should be selected")
        
        list.click()
        assertPicked(list,    "List segment should be selected")
    }
    
    func test_rankings_selection_populatesInspectorProfile() {
        launch()
        element(AccessibilityID.sidebarDestination("rankings")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.rankingRow(1, "Liren Ding"))))
        
        element(AccessibilityID.rankingRow(1, "Liren Ding")).click()
        element(AccessibilityID.rankingsInspectorToggle).click()
        
        XCTAssertTrue(waitFor(element(AccessibilityID.rankingsInspectorProfile)),
                      "Inspector should show the selected player's ranking")
    }
    
    // MARK: Smart Tags (M-prs.5)
    
    /// The whole create loop: + opens the editor, a named tag saves,
    /// appears in the sidebar, and filters the Library when clicked (its
    /// blank default rule matches nothing — the inert-new-tag contract —
    /// so the filtered Library renders its empty state, which still
    /// lives inside the content area the assertion targets).
    func test_tags_createSaveAndFilter() {
        launch()
        element(AccessibilityID.sidebarTagsAdd).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.tagsEditor)),
                      "Editor sheet should appear")
        
        let nameField = element(AccessibilityID.tagsEditorName)
        nameField.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText("Blitz")
        element(AccessibilityID.tagsEditorSave).click()
        
        XCTAssertTrue(waitFor(element(AccessibilityID.sidebarTag("Blitz"))),
                      "Saved tag should appear in the sidebar")
        element(AccessibilityID.sidebarTag("Blitz")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)),
                      "Tag-filtered Library should render")
    }
    
    // MARK: Library Filter Chip (M-prs.6)
    
    /// The chip round-trip: "Show in Library" on a Players row enters a
    /// programmatic player filter — no sidebar row exists for it, so the
    /// chip is the state's one visible face — and clearing the chip
    /// returns the full Library. The menu item is driven by *title* (the
    /// `launch()` helper's own menu-item pattern). The closing absence
    /// assertion is safe against the F8 vacuous-absence trap because the
    /// same constant is proven present two steps earlier in this test.
    func test_playerFilterChip_roundTripsThroughShowInLibrary() {
        launch()
        element(AccessibilityID.sidebarDestination("players")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.playerRow("Anish Giri"))),
                      "Players list should show the seeded player")
        
        element(AccessibilityID.playerRow("Anish Giri")).rightClick()
        let showInLibrary = app.menuItems["Show in Library"]
        XCTAssertTrue(showInLibrary.waitForExistence(timeout: 3),
                      "The row context menu should offer Show in Library")
        showInLibrary.click()
        
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryFilterChip)),
                      "The player-filtered Library should show its chip")
        element(AccessibilityID.libraryFilterChipClear).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)),
                      "Clearing the chip should land on the Library")
        XCTAssertFalse(element(AccessibilityID.libraryFilterChip).exists,
                       "The chip should be gone once the filter is cleared")
    }
    
    // MARK: Board Render (regression guard)
    
    /// Selecting Board with no game loaded must render the live physical-board
    /// mirror (identified `board`) and must NOT crash the app.
    ///
    /// Regression guard for the un-injected-observable trap: `BoardDestination`
    /// reads `@Environment(DGTLiveSession.self)` (and `DGTConnection`)
    /// non-optionally. If `DGTLiveSession` isn't injected at the `WindowGroup`
    /// content root, the first render of the Board destination traps the
    /// process ("No Observable object of type DGTLiveSession found"). A normal
    /// launch lands on Library, so only a test that actually navigates to Board
    /// exercises this path — which is precisely how the trap reached `main`
    /// undetected. The explicit `runningForeground` assertion documents that the
    /// failure mode being guarded is process death, not just a missing view.
    func test_boardDestination_rendersLiveMirror_withoutCrashing() {
        launch()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)))
        
        element(AccessibilityID.sidebarDestination("board")).click()
        
        XCTAssertTrue(waitFor(element(AccessibilityID.board), 8),
                      "Board destination should render the live mirror with no game loaded")
        XCTAssertEqual(app.state, .runningForeground,
                       "Rendering the Board destination must not crash the app")
    }
    
    func test_openSeededGame_showsBoard() {
        launch()
        
        // Switch to Icons so the seeded game renders as a tappable card.
        let icons = segment(ModeSymbol.icons)
        XCTAssertTrue(icons.waitForExistence(timeout: 5))
        if !isPicked(icons) { icons.click() }
        
        let card = element(AccessibilityID.gameCard(SeedGameName.quickMate))
        XCTAssertTrue(waitFor(card), "Seeded game card should exist in Icons mode")
        card.doubleClick()
        
        XCTAssertTrue(waitFor(element(AccessibilityID.board), 8),
                      "Board should appear after opening a game")
        XCTAssertFalse(element(AccessibilityID.sidebarLoadError).exists,
                       "A seeded game with legal moves should not hit the error state")
        XCTAssertFalse(element(AccessibilityID.sessionPanel).exists,
                       "With no board and no error, the sidebar session panel is absent (D15′)")
        // Same regression guard from the game-loaded entry point: opening a game
        // starts the tab on Board, so an un-injected DGTLiveSession would trap
        // here too.
        XCTAssertEqual(app.state, .runningForeground,
                       "Opening a game must not crash the app")
    }
    
    func test_libraryInspectorToggle_isHittable() {
        launch()
        let toggle = element(AccessibilityID.libraryInspectorToggle)
        XCTAssertTrue(waitFor(toggle), "Library inspector toggle should be in the toolbar")
        toggle.click()
        toggle.click()
        XCTAssertTrue(element(AccessibilityID.sidebar).exists,
                      "App should remain responsive after toggling the inspector")
    }
    
    func test_importButton_exists() {
        launch()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryImportButton)),
                      "Import button should be in the Library toolbar")
    }
    
    /// The Analyze toolbar button queues any non-empty selection since
    /// M-batch: disabled with nothing selected, enabled for one game,
    /// and — the changed contract — still enabled after ⌘A selects all
    /// four seeded games (the pre-M-batch button disabled itself for any
    /// multi-selection). Also pins the queue-status toolbar item's
    /// *absence* while the queue is idle, the same absence pattern the
    /// board's load-error banner test uses. Deliberately stops short of
    /// clicking Analyze — that would launch live Stockfish passes (and
    /// mutate the seeded PGNs' evaluations), which belongs to the manual
    /// checklist, not the smoke suite.
    func test_analyzeButton_enablesForAnySelection_queueItemAbsentWhileIdle() {
        launch()
        
        let analyze = element(AccessibilityID.libraryAnalyzeButton)
        XCTAssertTrue(waitFor(analyze), "Analyze button should be in the Library toolbar")
        XCTAssertFalse(analyze.isEnabled, "Analyze should be disabled with no selection")
        XCTAssertFalse(element(AccessibilityID.libraryQueueStatus).exists,
                       "Queue-status item should be absent while the queue is idle")
        
        // Force List mode (view mode persists in UserDefaults across runs),
        // then select a seeded row.
        let list = segment(ModeSymbol.list)
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        if !isPicked(list) { list.click() }
        
        let row = element(AccessibilityID.gameRow(SeedGameName.quickMate))
        XCTAssertTrue(waitFor(row), "Seeded game row should exist in List mode")
        row.click()
        
        // Poll briefly (same idiom as assertPicked) to absorb the
        // selection → toolbar-state update latency.
        var deadline = Date().addingTimeInterval(3)
        while Date() < deadline, !analyze.isEnabled {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(analyze.isEnabled, "Analyze should enable for a single selection")
        
        // ⌘A with the table focused selects all seeded games; the old
        // single-game guard disabled the button here.
        app.typeKey("a", modifierFlags: .command)
        deadline = Date().addingTimeInterval(3)
        while Date() < deadline, !analyze.isEnabled {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(analyze.isEnabled, "Analyze should stay enabled for a multi-selection")
    }
    
    // MARK: Command Menus (M9)
    
    /// Pins both halves of the M8.1 wiring in one flip: the `Commands`
    /// scene installed on the `WindowGroup` (the items exist), and
    /// `BoardDestination`'s `.focusedSceneValue` publishing (the items
    /// *enable* once a game-loaded tab is frontmost). The disabled state
    /// at launch is asserted first because it carries its own why: with
    /// no game focused, the bare-arrow key equivalents must stay
    /// unconsumed so sidebar/list arrow navigation keeps working — the
    /// exact gating `GameNavigationCommands`' doc comment defends.
    func test_gameMenu_itemsGateOnFocusedGame() {
        launch()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)))
        
        let menuBar = app.menuBars
        let gameMenu = menuBar.menuBarItems["Game"]
        XCTAssertTrue(gameMenu.waitForExistence(timeout: 5),
                      "Game menu should be installed on the menu bar")
        
        // Library frontmost, no game focused → all four items disabled.
        gameMenu.click()
        for title in ["First Move", "Previous Move", "Next Move", "Last Move"] {
            let item = menuBar.menuItems[title]
            XCTAssertTrue(item.waitForExistence(timeout: 3),
                          "\(title) should exist in the Game menu")
            XCTAssertFalse(item.isEnabled,
                           "\(title) should be disabled with no game focused")
        }
        app.typeKey(.escape, modifierFlags: [])
        
        // Open a seeded game (same idiom as test_openSeededGame_showsBoard);
        // the game window becomes frontmost and publishes its Game.
        let icons = segment(ModeSymbol.icons)
        XCTAssertTrue(icons.waitForExistence(timeout: 5))
        if !isPicked(icons) { icons.click() }
        let card = element(AccessibilityID.gameCard(SeedGameName.quickMate))
        XCTAssertTrue(waitFor(card), "Seeded game card should exist in Icons mode")
        card.doubleClick()
        XCTAssertTrue(waitFor(element(AccessibilityID.board), 8),
                      "Board should appear after opening a game")
        
        // Menu validation happens as the menu opens, so poll by
        // reopening rather than holding it open while the focused
        // value propagates.
        let nextMove = menuBar.menuItems["Next Move"]
        let deadline = Date().addingTimeInterval(5)
        var enabled = false
        while Date() < deadline, !enabled {
            gameMenu.click()
            enabled = nextMove.exists && nextMove.isEnabled
            if !enabled {
                app.typeKey(.escape, modifierFlags: [])
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            }
        }
        XCTAssertTrue(enabled,
                      "Game menu items should enable once a loaded game is frontmost")
        for title in ["First Move", "Previous Move", "Last Move"] {
            XCTAssertTrue(menuBar.menuItems[title].isEnabled,
                          "\(title) should be enabled with a game focused")
        }
        app.typeKey(.escape, modifierFlags: [])
    }
    
    /// Diagnostics menu presence and its connection gate: Export Session
    /// Log… is always available (a log needn't wait for a desync to be
    /// worth saving), while Start Board Recording is disabled because the
    /// seeded run has no board — `autoConnectAtLaunch()` is skipped under
    /// the UI-test seed precisely so no hardware can feed this suite, so
    /// `isConnected` is deterministically false here. Seeing Start rather
    /// than Stop & Export also pins the not-recording branch. No item is
    /// ever clicked: both actions raise save panels or touch the
    /// connection — manual-checklist territory.
    func test_diagnosticsMenu_exportAvailable_recordingGatedOnConnection() {
        launch()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)))
        
        let menuBar = app.menuBars
        let diagnostics = menuBar.menuBarItems["Diagnostics"]
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 5),
                      "Diagnostics menu should be installed on the menu bar")
        diagnostics.click()
        
        let export = menuBar.menuItems["Export Session Log"]
        XCTAssertTrue(export.waitForExistence(timeout: 3),
                      "Export Session Log should exist")
        XCTAssertTrue(export.isEnabled,
                      "Export Session Log should be enabled")
        
        let start = menuBar.menuItems["Start Board Recording"]
        XCTAssertTrue(start.waitForExistence(timeout: 3),
                      "Start Board Recording should exist while not recording")
        XCTAssertFalse(start.isEnabled,
                       "Start Board Recording should be disabled with no board connected")
        
        XCTAssertFalse(menuBar.menuItems["Stop & Export Board Recording…"].exists,
                       "Stop & Export should be absent while not recording")
        
        app.typeKey(.escape, modifierFlags: [])
    }
    
    func test_launchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
