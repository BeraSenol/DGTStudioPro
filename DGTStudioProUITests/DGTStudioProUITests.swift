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
//  Requires the accessibilityIdentifier edits in the app target and
//  DGTStudioProApp's `.defaultLaunchBehavior(.presented)`. `launch()`
//  also opens a window via File ▸ New Window as a fallback, since a
//  value-based WindowGroup may still present no window on a clean,
//  in-memory test launch.
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

    // Mirrored from `UITestSeed.GameName` (separate module — keep in sync).
    private enum SeedGame {
        static let quickMate = "Quick Mate"
        static let ruyLopez  = "Ruy Lopez"
        static let drawnGame = "Drawn Game"
        static let blackWins = "Black Wins"
    }

    // View-mode segment handles: the SF Symbol name each mode uses.
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
        XCTAssertTrue(waitFor(element("sidebar")),
                      "Sidebar should be present at launch")
        XCTAssertTrue(waitFor(element("library.content")),
                      "Library should be the default destination")
    }

    func test_sidebar_navigatesToEachDestination() {
        launch()
        XCTAssertTrue(waitFor(element("library.content")))

        element("sidebar.board").click()
        XCTAssertTrue(waitFor(element("board.landing")),
                      "Board should show its landing state (no game loaded)")

        element("sidebar.players").click()
        XCTAssertTrue(waitFor(element("players.content")),
                      "Players destination should appear")

        element("sidebar.rankings").click()
        XCTAssertTrue(waitFor(element("rankings.content")),
                      "Rankings destination should appear")

        element("sidebar.library").click()
        XCTAssertTrue(waitFor(element("library.content")),
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
        element("sidebar.tag.checkmate").click()
        XCTAssertTrue(waitFor(element("library.content")),
                      "Tag-filtered Library should render its content area")
    }

    func test_openSeededGame_showsBoard() {
        launch()

        // Switch to Icons so the seeded game renders as a tappable card.
        let icons = segment(ModeSymbol.icons)
        XCTAssertTrue(icons.waitForExistence(timeout: 5))
        if !isPicked(icons) { icons.click() }

        let card = element("gameCard.\(SeedGame.quickMate)")
        XCTAssertTrue(waitFor(card), "Seeded game card should exist in Icons mode")
        card.doubleClick()

        XCTAssertTrue(waitFor(element("board"), 8),
                      "Board should appear after opening a game")
        XCTAssertFalse(element("board.error").exists,
                       "A seeded game with legal moves should not hit the error state")
    }

    func test_libraryInspectorToggle_isHittable() {
        launch()
        let toggle = element("library.inspectorToggle")
        XCTAssertTrue(waitFor(toggle), "Library inspector toggle should be in the toolbar")
        toggle.click()
        toggle.click()
        XCTAssertTrue(element("sidebar").exists,
                      "App should remain responsive after toggling the inspector")
    }

    func test_importButton_exists() {
        launch()
        XCTAssertTrue(waitFor(element("library.importButton")),
                      "Import button should be in the Library toolbar")
    }

    func test_launchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
