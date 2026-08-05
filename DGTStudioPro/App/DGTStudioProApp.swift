//
//  DGTStudioProApp.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import AppKit
import SwiftData
import SwiftUI

@main
@MainActor
internal struct DGTStudioProApp: App {
    
    /// Shared `ModelContainer` for the whole app. Multiple tabs share
    /// one container so `PersistentIdentifier`s round-trip correctly.
    ///
    /// Always the persistent store now. This used to branch on the
    /// `-uiTestSeed` launch argument into an in-memory container pre-seeded
    /// with sample games; the UI test suite was deleted 3 Aug 2026 and the
    /// branch went with it, along with `UITestSeed` itself. What remains is
    /// the plain path that every real launch always took.
    private let sharedContainer: ModelContainer = {
        do {
            // Player joins the schema explicitly (M-prs.1), SmartTag in
            // M-prs.5 — SmartTag has no relationships, so inference would
            // NOT pull it in; listing all three is load-bearing now, not
            // just documentation.
            let container = try ModelContainer(
                for: PGN.self, Player.self, SmartTag.self,
                configurations: ModelConfiguration()
            )
            SmartTag.seedDefaultsOnce(into: container)
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
    
    /// M-ux.2 (D14′) — the idle-sleep inhibition token holder. App-owned
    /// like the DGT observables (its tracking loop must outlive every
    /// view). Injected into the **Settings scene only** (D25′: it owns the
    /// user gate, which Settings binds to); deliberately not injected into
    /// the `WindowGroup` — no destination renders or reads it.
    @State private var sleepInhibitor: SleepInhibitor

    /// M8 (D45′) — which inspector sections are folded shut. App-owned and
    /// injected into the `WindowGroup`, unlike `sleepInhibitor` above: this
    /// one *is* read by destinations, by every inspector in every tab, and
    /// the state is deliberately shared across tabs. Collapsing Opening is a
    /// statement about openings, not about the window it was made in.
    ///
    /// Handed `.standard` explicitly. The injectable-defaults seam on
    /// `InspectorSectionCollapse` outlived the reason it was added: it existed
    /// so a seeded UI run wouldn't read the developer's own collapsed
    /// sections, and the UI suite is gone. The seam stays because the
    /// previews still need it — a canvas writing into real preferences is the
    /// same leak with a smaller blast radius — but this call site no longer
    /// has anything to choose between.
    @State private var inspectorCollapse = InspectorSectionCollapse(defaults: .standard)

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
        
        // M2 (D28′) — the board identity the new game stamps onto its
        // roster. Strong capture, deliberately, same as the tracking loop's
        // (the @Sendable weak-capture lesson does not apply to a plain
        // @MainActor closure): session → connection is the only strong edge
        // — the connection's own hooks capture the session weakly — so no
        // cycle, and both objects are App-owned for the process lifetime
        // anyway.
        session.boardIdentity = {
            connection.boardInfo.identityTag
        }

        // D49′ — the `.unresolved` pre-flight: the session suspects, the
        // connection asks the hardware for a full dump, and recovery only
        // takes over if the dump-confirmed board still can't be explained.
        // Strong capture, `boardIdentity`'s reasoning above.
        session.requestBoardResync = {
            connection.requestBoardResync()
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
        
        // M-ux.1 (D13′) — the illegal-move cue. The session fires this from
        // `enterRecovery`, so it sounds exactly once per desync entry.
        // AppKit because SwiftUI has no sound API; `NSSound.beep()` is the
        // system alert — respects the user's alert sound and volume, no
        // bundled asset, deliberately. The `?? true` here is the
        // `@AppStorage` twin in `SettingsView` — the `autoConnectOnLaunch`
        // contract, documented in `StorageKeys`.
        //
        // The seeded-run silence guard is gone with the UI suite (3 Aug
        // 2026). Unit tests never reach this closure — a nil `onDesync` is
        // what makes them headless by construction — so the preference is
        // now the only thing standing between a desync and a beep.
        session.onDesync = {
            let enabled = UserDefaults.standard
                .object(forKey: StorageKeys.illegalMoveSoundEnabled) as? Bool ?? true
            if enabled { NSSound.beep() }
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
        
        // M-ux.2 (D14′) — start the inhibition observer. Wired here, once,
        // like every other hook: the content closure runs per tab, and two
        // tabs must not race one token.
        let inhibitor = SleepInhibitor()
        inhibitor.observe(session: session, connection: connection)
        
        // M7.2 — reconnect to the remembered board at launch (the Settings
        // toggle and the remembered-device check both live inside the
        // call). A Task from this main-actor init runs after init returns,
        // so first render isn't held hostage to IOKit enumeration plus the
        // serial handshake.
        //
        // Skipped under the unit-test host: ⌘U launches
        // this very app as the test host, and a board attached during a
        // run would put serial I/O, the staggered init handshake, and live
        // board-change traffic on the main actor for the entire suite —
        // competing with timing-sensitive tests (the 300 ms quiescence
        // window) and feeding the app-global session real hardware events
        // mid-run. The test host must stay hermetic. XCTest marks its host
        // process with these environment variables (Swift Testing runs
        // under the same harness in Xcode). The guard's UI-test half
        // retired with the suite (3 Aug 2026, D51′); this env-var check
        // was always the unit half.
        // `TestHost` since 5 Aug 2026 — this probe was spelled here and
        // nowhere else until `AppLog` needed the same answer, at which point
        // two copies of an environment check would have been D25′'s twin read
        // site with a hermetic test suite riding on it.
        if !TestHost.isActive {
            Task { await connection.autoConnectAtLaunch() }
        }
        
        _dgtConnection = State(initialValue: connection)
        _dgtSession = State(initialValue: session)
        _sessionLog = State(initialValue: log)
        _sleepInhibitor = State(initialValue: inhibitor)
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
        // `WindowGroup` otherwise opens NO window on a clean launch — it
        // normally relies on session restoration to reopen windows. (The
        // UI suite's in-memory launches hit this on every run before it
        // retired; a fresh machine hits it once.)
        WindowGroup("DGT Studio Pro", for: PersistentIdentifier.self) { $gameID in
            ContentView(loadedGameID: $gameID)
                .environment(openGames)
                .environment(dgtConnection)
                .environment(dgtSession)
                .environment(sessionLog)
                .environment(inspectorCollapse)
            // No `.defaultAppStorage(_:)` here any more. It redirected every
            // `@AppStorage` in the tab to a wiped scratch suite under the
            // `-uiTestSeed` argument, so a UI run couldn't read — or write —
            // the developer's real preferences. With the suite deleted the
            // expression could only ever evaluate to `.standard`, which is
            // the environment default, so the modifier said nothing.
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
            // File ▸ New Smart Tag… — the AX-reachable door into the
            // D12′ editor; the sidebar header's + is pointer-only (see
            // `SmartTagCommands` for the evidence).
            SmartTagCommands()
        }
        
        // M8 (D46′) — the enlarged evaluation graph. A separate group so it can
        // sit beside the board while the reader steps through the game; macOS
        // only tabs windows from the same group, which is exactly what this one
        // must *not* do with the game windows above.
        //
        // Keyed on `EvaluationGraphRequest` and not on `PersistentIdentifier`:
        // `openWindow(value:)` routes by value type, the group above already
        // claims that type, and three call sites depend on it. See the request
        // type for the full reason — the short version is that the routing is
        // now a fact about the type system rather than about which scene was
        // declared first.
        //
        // (This scene spent part of 4 Aug 2026 deleted, the graph a popover;
        // reverted the same night — the D46′ anchor records the round trip.)
        WindowGroup("Evaluation", for: EvaluationGraphRequest.self) { $request in
            EvaluationGraphWindow(request: request)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 720, height: 420)
        // D46′ delta (2 Aug 2026, Bera's call): the graph hovers in front
        // of the game windows rather than stacking with them. Floating
        // level, not a popover — a popover dismisses on the first board
        // click, which is exactly the companion-while-scrubbing use D46′
        // chose a window to protect.
        .windowLevel(.floating)

        // M10 — Get Info. One group for all three subjects (a game, the
        // recording, a player), which is what makes two info windows tab with
        // *each other* rather than with the boards: macOS tabs within a group,
        // and two rosters side by side is a comparison while an info window
        // tabbed behind a board is a window you lost.
        //
        // Keyed on `GetInfoRequest` for the reason D46′ established one scene
        // up: `openWindow(value:)` routes by value type, the first group above
        // claims `PersistentIdentifier`, and five call sites depend on that.
        // The enum pays that cost once for three subjects instead of three
        // times.
        //
        // Deliberately *not* `.windowLevel(.floating)`, unlike the graph. The
        // graph floats because it is read while the board underneath is
        // driven; Get Info is edited, so it takes focus, and a floating window
        // that owns the keyboard while sitting over everything is the shape
        // people file bugs about.
        WindowGroup("Info", for: GetInfoRequest.self) { $request in
            GetInfoWindow(request: request)
                .environment(dgtSession)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 460, height: 520)

        Settings {
            SettingsView()
                .environment(sleepInhibitor)
        }
        .modelContainer(sharedContainer)
    }
}
