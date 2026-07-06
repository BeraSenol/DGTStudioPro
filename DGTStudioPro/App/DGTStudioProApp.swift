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
            let container = try ModelContainer(for: PGN.self, configurations: config)
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

        Settings {
            SettingsView()
        }
        .modelContainer(sharedContainer)
    }
}
