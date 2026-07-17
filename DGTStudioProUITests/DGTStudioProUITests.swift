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

    // MARK: - Launch

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

    // MARK: - Helpers

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

    // MARK: - Tests

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
        element(AccessibilityID.sidebarTag("checkmate")).click()
        XCTAssertTrue(waitFor(element(AccessibilityID.libraryContent)),
                      "Tag-filtered Library should render its content area")
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
        XCTAssertFalse(element(AccessibilityID.boardLoadError).exists,
                       "A seeded game with legal moves should not hit the error state")
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

    /// The Analyze toolbar button is a single-game action: always present,
    /// enabled only once exactly one game is selected. Deliberately stops
    /// short of clicking it while enabled — that would launch a Stockfish
    /// pass (and mutate the seeded PGN's evaluations), which belongs to a
    /// manual checklist, not the smoke suite.
    func test_analyzeButton_existsAndEnablesWithSingleSelection() {
        launch()

        let analyze = element(AccessibilityID.libraryAnalyzeButton)
        XCTAssertTrue(waitFor(analyze), "Analyze button should be in the Library toolbar")
        XCTAssertFalse(analyze.isEnabled, "Analyze should be disabled with no selection")

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
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline, !analyze.isEnabled {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(analyze.isEnabled, "Analyze should enable once a single game is selected")
    }

    func test_launchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
