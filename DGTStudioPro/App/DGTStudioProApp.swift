import AppKit
import SwiftData
import SwiftUI

@main
@MainActor
internal struct DGTStudioProApp: App {
    
    /// Shared `ModelContainer` for the whole app. Multiple tabs share
    /// one container so `PersistentIdentifier`s round-trip correctly.
    ///
    /// Always the persistent store. This branched on a `-uiTestSeed` argument
    /// into a pre-seeded in-memory container until D51′ deleted the suite; what
    /// remains is the path every real launch always took.
    private let sharedContainer: ModelContainer = {
        do {
            // All three listed explicitly, which is load-bearing rather than
            // documentation: `SmartTag` has no relationships, so schema
            // inference from `PGN` would never pull it in.
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

    /// The app's one engine-analysis queue (controller decision 2, reversed
    /// from per-tab on 6 Aug 2026).
    ///
    /// Here for the reason `openGames` is here: one object, every window sees
    /// the same one, and the queue window below could not be handed a
    /// particular tab's instance in any case — a scene receives values, not
    /// references. Injected into the main `WindowGroup` so destinations read it
    /// from the environment, and read directly by the queue window's scene.
    ///
    /// Constructed in `init()` rather than inline since D66′, joining the DGT
    /// observables for the same reason they are there: something has to be
    /// *wired* to it once, and `init()` is the only place that runs exactly
    /// once. `SleepInhibitor` now observes this queue, and an inline default
    /// cannot be read from `init()` before the stored properties are assigned.
    @State private var analysisQueue: AnalysisQueueController
    
    // The three app-global DGT observables.
    //
    // Every registry — these plus `openGames` — must be injected into the
    // `WindowGroup` below, or a destination reading one traps at runtime with
    // "No Observable object of type … found". That was a real crash, not a
    // hypothetical: previews injected them and the App did not, so ghost-rook
    // rendering was preview-correct while the app died the moment Board showed.
    //
    // Constructed and wired in `init()` rather than inline in the content
    // closure, because that closure runs once per tab — an inline
    // `connection.onBoardChanged = …` would re-point the hook on every new one.
    // `App.init()` runs exactly once.
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

    /// 7 Aug 2026 — the View Options panel's subject: icon size, grid spacing,
    /// and both collection destinations' sorts. `inspectorCollapse`'s
    /// arrangement exactly, and for its reasons: app-owned because the state is
    /// shared across tabs (an icon size is a statement about browsing, not
    /// about the window it was set in), injected into the `WindowGroup` because
    /// destinations read it, and handed `.standard` explicitly because the
    /// injectable seam exists for the previews rather than for this site.
    ///
    /// It is also injected into the View Options scene itself, which is the one
    /// place the value is *written* — a panel bound to a different instance
    /// than the grids read would be a slider that moves nothing.
    @State private var viewOptions = CollectionViewOptions(defaults: .standard)

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
        
        // M-ux.2 (D14′, widened by D66′) — start the inhibition observer.
        // Wired here, once, like every other hook: the content closure runs
        // per tab, and two tabs must not race one token.
        //
        // The queue is constructed here rather than inline for exactly this:
        // the inhibitor has to be handed the same instance every window sees,
        // and there is only one because the controller went app-global on
        // 6 Aug. Under the per-tab controller this line could not have been
        // written at all.
        let analysis = AnalysisQueueController()
        let inhibitor = SleepInhibitor()
        inhibitor.observe(session: session, connection: connection, analysis: analysis)
        
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
        _analysisQueue = State(initialValue: analysis)
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
                .environment(analysisQueue)
                .environment(dgtConnection)
                .environment(dgtSession)
                .environment(sessionLog)
                .environment(inspectorCollapse)
                .environment(viewOptions)
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
            // 7 Aug 2026 — View ▸ Show View Options (⌘J). The publishing side
            // is `.focusedSceneValue(\.collectionViewOptionsSubject, …)` on
            // both collection destinations, so the item is enabled only when a
            // Library or Players tab is in front and disabled over a Board.
            CollectionViewOptionsCommands()
        }
        
        // M8 (D46′) — the enlarged evaluation graph. A separate group so it can
        // sit beside the board while the reader steps through the game; macOS
        // only tabs windows from the same group, which is exactly what this one
        // must *not* do with the game windows above.
        //
        // Keyed on `EvaluationGraphRequest`, not `PersistentIdentifier`: the
        // group above claims that type and `openWindow(value:)` routes by type.
        // Full reason at the request type.
        //
        // (Deleted for part of 4 Aug 2026, the graph a popover; reverted the
        // same night — the D46′ anchor records the round trip.)
        WindowGroup("Evaluation", for: EvaluationGraphRequest.self) { $request in
            EvaluationGraphWindow(request: request)
                .fullScreenAuxiliary()
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 720, height: 420)
        // D46′ delta (2 Aug 2026, Bera's call): the graph hovers in front
        // of the game windows rather than stacking with them. Floating
        // level, not a popover — a popover dismisses on the first board
        // click, which is exactly the companion-while-scrubbing use D46′
        // chose a window to protect.
        .windowLevel(.floating)

        // D73′ (8 Aug 2026) — the analysis as data: every ply's evaluation in
        // a table, opened from the button beside the magnifier in the Library
        // inspector's Evaluation header. Keyed on `AnalysisDataRequest`, the
        // fourth wrapper in the `openWindow(value:)` family — this scene has a
        // subject, so it pays the wrapper the singleton scenes sidestep.
        //
        // Deliberately *not* `.windowLevel(.floating)`, unlike the graph one
        // block up: a table is scrolled and text-selected, so it takes focus,
        // and the Get Info argument applies.
        WindowGroup("Analysis Data", for: AnalysisDataRequest.self) { $request in
            AnalysisDataWindow(request: request)
                .fullScreenAuxiliary()
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 460, height: 520)

        // M10 — Get Info. One group for all three subjects (a game, the
        // recording, a player), which is what makes two info windows tab with
        // *each other* rather than with the boards: macOS tabs within a group,
        // and two rosters side by side is a comparison while an info window
        // tabbed behind a board is a window you lost.
        //
        // Keyed on `GetInfoRequest` for the reason D46′ established one scene
        // up, and the enum pays that cost once for three subjects rather than
        // three times. D53′.
        //
        // Deliberately *not* `.windowLevel(.floating)`, unlike the graph. The
        // graph floats because it is read while the board underneath is
        // driven; Get Info is edited, so it takes focus, and a floating window
        // that owns the keyboard while sitting over everything is the shape
        // people file bugs about.
        WindowGroup("Info", for: GetInfoRequest.self) { $request in
            GetInfoWindow(request: request)
                .environment(dgtSession)
                .fullScreenAuxiliary()
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 460, height: 520)

        // 6 Aug 2026 — the analysis queue's own window, replacing the Library
        // toolbar's popover.
        //
        // **A `Window`, not a `WindowGroup`, and this is the first scene in the
        // app that needs no wrapper type.** D46′ and D53′ both had to mint one
        // (`EvaluationGraphRequest`, `GetInfoRequest`) because
        // `openWindow(value:)` routes by the value's type and the main group
        // already claims `PersistentIdentifier`. There is nothing to route
        // here: there is exactly one queue, so the window is a singleton opened
        // by `openWindow(id:)` and the whole trap is sidestepped rather than
        // paid for a third time. That is a *consequence* of decision 2 going
        // app-global, and the cleanest evidence that it was the right call.
        //
        // `.defaultLaunchBehavior(.suppressed)` because a `Window` scene opens
        // itself at launch otherwise — the opposite of the value-based groups
        // above, which open none and needed `.presented` forced onto the main
        // one. A queue window over an idle queue on every cold launch is a
        // window nobody asked for.
        //
        // Not `.windowLevel(.floating)`, deliberately, and the D46′ split is
        // the precedent: the graph floats because it is *read* while the board
        // underneath is driven. This one is read the same way — but it also
        // carries Stop All and per-row removal, so it takes clicks, and a
        // window that owns destructive controls while sitting permanently over
        // everything is the shape people file bugs about (the argument Get Info
        // already makes one scene down).
        Window("Analysis", id: AnalysisQueueStatusWindowView.sceneID) {
            AnalysisQueueStatusWindowView()
                .environment(analysisQueue)
                .fullScreenAuxiliary()
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 520, height: 560)
        .defaultLaunchBehavior(.suppressed)

        // 7 Aug 2026 — Finder's ⌘J for the two collection destinations.
        //
        // A `Window` and not a `WindowGroup`, the Analysis scene's precedent
        // one block up and for the same reason: there is exactly one panel, so
        // it opens by `id` and needs no wrapper type to keep
        // `openWindow(value:)` unambiguous. Third scene in a row to sidestep
        // the trap D46′ and D53′ each had to pay for.
        //
        // No `modelContainer`: the panel reads and writes `CollectionViewOptions`
        // and touches no model. Withholding it is the check — if this window
        // ever needs the store, that is a signal the panel has grown into
        // something other than a view-options panel.
        //
        // `.floating`, unlike Get Info and Analysis, and the D46′ split is the
        // precedent read the other way: the graph floats because it is read
        // while the board underneath is driven, and this is *worse* than that —
        // its whole purpose is to be manipulated while watching the grid behind
        // it resize. A panel that sinks behind the window it is resizing is
        // useless in the one moment it exists for. The counter-argument that
        // kept Get Info and Analysis unfloated (a window owning the keyboard
        // over everything) does not apply: this one carries sliders and
        // pickers, no destructive control and no text entry.
        Window("View Options", id: CollectionViewOptionsWindow.sceneID) {
            CollectionViewOptionsWindow()
                .environment(viewOptions)
                .fullScreenAuxiliary()
        }
        .defaultSize(width: 340, height: 300)
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentMinSize)
        .windowLevel(.floating)

        Settings {
            SettingsView()
                .environment(sleepInhibitor)
        }
        .modelContainer(sharedContainer)
    }
}
