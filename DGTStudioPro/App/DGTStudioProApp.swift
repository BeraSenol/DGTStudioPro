//
//  DGTStudioProApp.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftData
import SwiftUI

@main
@MainActor
internal struct DGTStudioProApp: App {
    
    /// Shared `ModelContainer` for the whole app. Multiple tabs share
    /// one container so `PersistentIdentifier`s round-trip correctly.
    ///
    /// Under the `-uiTestSeed` launch argument the container is in-memory
    /// and pre-seeded with `UITestSeed`'s sample games, so UI tests run
    /// against deterministic data and never touch the real library. A
    /// normal launch is unaffected (persistent store, no seeding).
    private let sharedContainer: ModelContainer = {
        do {
            let inMemory = UITestSeed.isActive
            let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            // Player joins the schema explicitly (M-prs.1). Relationship
            // inference from PGN would pull it in regardless; listing it
            // keeps the full schema readable at its one source of truth.
            let container = try ModelContainer(for: PGN.self, Player.self, configurations: config)
            if inMemory { UITestSeed.seed(into: container) }
            return container
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
    
    /// Shared registry of open games with unsaved changes. Same
    /// create-once-on-the-App, inject-into-every-tab pattern as
    /// `sharedContainer`. Used by the Library's delete path to decide
    /// whether closing a deleted game's tab needs a discard confirmation.
    @State private var openGames = OpenGamesRegistry()
    
    // The three app-global DGT observables.
    //
    // ALL FOUR registries (these three plus `openGames`) must be injected
    // into the WindowGroup content below, or any destination that reads one
    // traps at runtime with "No Observable object of type … found."
    // `BoardDestination` reads `dgtConnection` AND `dgtSession`, so the Board
    // destination — and opening any game in a tab, which starts on Board —
    // depends on both being present. (This is exactly the injection that was
    // missing: ghost-rook rendering was "preview-correct" but the real app
    // crashed the moment Board was shown, because the previews injected these
    // and the App did not.)
    //
    // They are constructed and wired in `init()` rather than inline in the
    // content closure, because that closure runs once per window/tab — an
    // inline `connection.onBoardChanged = …` would re-point the hook on every
    // new tab. `App.init()` runs exactly once.
    @State private var dgtConnection: DGTConnection
    @State private var dgtSession: DGTLiveSession
    @State private var sessionLog: DGTSessionLog
    
    // The struct is `@MainActor` (above), so this init runs on the main actor
    // and may touch the `@MainActor` members of the DGT objects it wires. The
    // module's default actor isolation is `nonisolated`, so without that
    // annotation this would not compile — it touches main-actor-isolated state.
    init() {
        let log = DGTSessionLog()
        let connection = DGTConnection()
        let session = DGTLiveSession()
        
        // One diagnostic timeline shared by both objects, and the connection's
        // board changes feed the live session's quiescence driver. Wiring
        // happens here, once, not in view lifecycle.
        connection.sessionLog = log
        session.sessionLog = log
        connection.onBoardChanged = { [weak session] board in
            session?.boardChanged(board)
        }
        
        // M7.3 — a board vanishing mid-game auto-reconnects instead of
        // showing the failure banner. "Mid-game" is any game-bearing mode
        // (`liveGame` non-nil, finished-on-screen included: the finished
        // screen flows into next-game detection, and the start-position
        // offer can only come from a board that's actually streaming —
        // unplugged reads as `.empty` forever); the loop re-asks on every
        // lap, so a discard or return to idle stands it down. Wired here,
        // once, like every other hook.
        connection.shouldAutoReconnect = { [weak session] in
            session?.liveGame != nil
        }
        
        // Draft persistence (M4): the session owns when to save/delete; the
        // store owns the file. Loading here — once, after wiring — is what
        // turns a relaunch into the Resume / Delete offer on the Board HUD.
        let draftStore = LiveGameDraftStore()
        session.draftStore = draftStore
        
        // The archive door (M5): one PGNStore over the shared container's
        // main context; the session invokes it on every `isFinished`
        // transition (archive-first, before any UI) and on the resume
        // self-heal. Wired before `loadPendingDraft()` so any draft resumed
        // this run always has the door available.
        let pgnStore = PGNStore(modelContext: sharedContainer.mainContext)
        session.onGameFinished = { game in
            try pgnStore.archive(game)
        }
        
        session.loadPendingDraft()
        
        // M7.2 — reconnect to the remembered board at launch (the Settings
        // toggle and the remembered-device check both live inside the
        // call). A Task from this main-actor init runs after init returns,
        // so first render isn't held hostage to IOKit enumeration plus the
        // serial handshake.
        //
        // Skipped under UI tests (a developer's real remembered board must
        // not hijack a deterministic run) AND under unit tests: ⌘U launches
        // this very app as the test host, and a board attached during a
        // run would put serial I/O, the staggered init handshake, and live
        // board-change traffic on the main actor for the entire suite —
        // competing with timing-sensitive tests (the 300 ms quiescence
        // window) and feeding the app-global session real hardware events
        // mid-run. The test host must stay hermetic. XCTest marks its host
        // process with these environment variables (Swift Testing runs
        // under the same harness in Xcode).
        let environment = ProcessInfo.processInfo.environment
        let isUnitTestHost = environment["XCTestConfigurationFilePath"] != nil
        || environment["XCTestSessionIdentifier"] != nil
        if !UITestSeed.isActive && !isUnitTestHost {
            Task { await connection.autoConnectAtLaunch() }
        }
        
        _dgtConnection = State(initialValue: connection)
        _dgtSession = State(initialValue: session)
        _sessionLog = State(initialValue: log)
    }
    
    var body: some Scene {
        // One unified `WindowGroup` parameterised by an optional
        // `PersistentIdentifier`. Tabs with a nil value land on Library;
        // tabs with a value land on Board showing that game.
        //
        // With "Prefer Tabs: Always" in System Settings → Desktop &
        // Dock, additional windows of this group merge as native macOS
        // tabs of the existing window — Safari/Finder behavior. macOS
        // handles the tab bar, ⌘T, ⌘W, ⌘⇧[/], drag-rearrange, "Merge
        // All Windows," and window-state restoration.
        //
        // Library and Board can't tab together if they live in
        // separate `WindowGroup`s — macOS only tabs windows from the
        // same group. Hence one group, content varies by bound value.
        //
        // `.defaultLaunchBehavior(.presented)` forces an initial window
        // even when there is nothing to restore. A value-based
        // `WindowGroup` otherwise opens NO window on a clean launch (the
        // case in UI tests, where the in-memory store restores nothing) —
        // it normally relies on session restoration to reopen windows.
        WindowGroup("DGT Studio Pro", for: PersistentIdentifier.self) { $gameID in
            ContentView(loadedGameID: $gameID)
                .environment(openGames)
                .environment(dgtConnection)
                .environment(dgtSession)
                .environment(sessionLog)
        }
        .modelContainer(sharedContainer)
        .defaultLaunchBehavior(.presented)
        // M8.1 — install the long-built Game menu (First/Previous/Next/Last
        // with the ←/→/Home/End shortcuts). The publishing side
        // (`.focusedSceneValue(\.activeGame, …)`) has been live in
        // `BoardDestination` since Phase 11; this is the missing scene
        // half. M8.3 — the Diagnostics menu rides in the same block,
        // wiring the last unsurfaced diagnostics features; it takes the
        // app-global objects directly because diagnostics are app-scoped,
        // not per-tab.
        .commands {
            GameNavigationCommands()
            DiagnosticsCommands(connection: dgtConnection, sessionLog: sessionLog)
        }
        
        Settings {
            SettingsView()
        }
        .modelContainer(sharedContainer)
    }
}
