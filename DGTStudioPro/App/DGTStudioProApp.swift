import AppKit
import SwiftData
import SwiftUI

@main
@MainActor
internal struct DGTStudioProApp: App {
    
    /// Shared `ModelContainer`: tabs share one so `PersistentIdentifier`s round-trip.
    private let sharedContainer: ModelContainer = {
        do {
            // All three listed explicitly — load-bearing: `SmartTag` has no relationships, so schema
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
    
    /// Registry of open games with unsaved changes; the Library's delete path asks it whether a
    /// discard confirmation is needed.
    @State private var openGames = OpenGamesRegistry()

    /// The app's one analysis queue (app-global since 6 Aug — a scene receives values, not a tab's
    /// instance). Constructed here; `init()` is the only place that runs exactly once.
    @State private var analysisQueue: AnalysisQueueController
    
    // The three app-global DGT observables. Every registry must be injected into the WindowGroup or
    // a destination reading one traps at runtime — that was a real crash (previews injected, App didn't).
    @State private var dgtConnection: DGTConnection
    @State private var dgtSession: DGTLiveSession
    @State private var sessionLog: DGTSessionLog
    
    /// Sleep-inhibition token holder (D14′). Injected into **Settings only** (D25′: it owns the user
    /// gate); no destination reads it.
    @State private var sleepInhibitor: SleepInhibitor

    /// Which inspector sections are folded (D45′). Injected into the WindowGroup — every inspector
    /// reads it, shared across tabs: collapsing Opening is a statement about openings, not a window.
    @State private var inspectorCollapse = InspectorSectionCollapse(defaults: .standard)

    /// View Options subject — `inspectorCollapse`'s arrangement, for its reasons.
    @State private var viewOptions = CollectionViewOptions(defaults: .standard)

    // The struct is @MainActor, so this init may touch the DGT objects' main-actor members; the
    // module default is `nonisolated`, so without the annotation this would not compile.
    init() {
        let log = DGTSessionLog()
        let connection = DGTConnection()
        let session = DGTLiveSession()
        
        // One shared timeline; wiring happens here, once, not in view lifecycle.
        connection.sessionLog = log
        session.sessionLog = log
        connection.onBoardChanged = { [weak session] board in
            session?.boardChanged(board)
        }
        
        // D28′ — board identity stamped at game start. Strong capture, deliberately: session → connection
        // is the only strong edge (the connection's hooks capture the session weakly), so no cycle.
        session.boardIdentity = {
            connection.boardInfo.identityTag
        }

        // D49′ — session suspects, connection asks the hardware; recovery only after the dump fails too.
        session.requestBoardResync = {
            connection.requestBoardResync()
        }

        // M7.3 — mid-game vanish auto-reconnects. "Mid-game" is any game-bearing mode.
        connection.shouldAutoReconnect = { [weak session] in
            session?.liveGame != nil
        }
        
        // D13′ — the illegal-move cue, fired once per desync entry. `NSSound.beep()` respects the user's
        // alert sound (AppKit — SwiftUI has no sound API). The `?? true` is the Settings twin default.
        session.onDesync = {
            let enabled = UserDefaults.standard
                .object(forKey: StorageKeys.illegalMoveSoundEnabled) as? Bool ?? true
            if enabled { NSSound.beep() }
        }
        
        // M4 draft persistence: session owns when, store owns the file. Loading here is what turns a
        // relaunch into the Resume / Delete offer.
        let draftStore = LiveGameDraftStore()
        session.draftStore = draftStore
        
        // M5 archive door, wired before `loadPendingDraft()` so a resumed draft always has it.
        let pgnStore = PGNStore(modelContext: sharedContainer.mainContext)
        session.onGameFinished = { game in
            try pgnStore.archive(game)
        }
        
        session.loadPendingDraft()
        
        // D14′/D66′ — the inhibition observer, wired once: the content closure runs per tab, and two
        // tabs must not race one token.
        let analysis = AnalysisQueueController()
        let inhibitor = SleepInhibitor()
        inhibitor.observe(session: session, connection: connection, analysis: analysis)
        
        // M7.2 — launch auto-connect in a Task so first render isn't held hostage to IOKit + handshake.
        // Guarded by `TestHost.isActive`: a real board must not feed the unit suite hardware events (hermetic host).
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
        // One unified WindowGroup over `PersistentIdentifier?`: nil → Library, value → Board with that
        // game. One group is what makes macOS tab the windows together under "Prefer Tabs: Always".
        WindowGroup("DGT Studio Pro", for: PersistentIdentifier.self) { $gameID in
            ContentView(loadedGameID: $gameID)
                .environment(openGames)
                .environment(analysisQueue)
                .environment(dgtConnection)
                .environment(dgtSession)
                .environment(sessionLog)
                .environment(inspectorCollapse)
                .environment(viewOptions)
        }
        .modelContainer(sharedContainer)
        .defaultLaunchBehavior(.presented)
        // M8.1 Game menu (←/→/Home/End) — the scene half of `.focusedSceneValue(\.activeGame, …)`.
        // Diagnostics rides in the same block; commands are app-scoped, not per-tab.
        .commands {
            GameNavigationCommands()
            DiagnosticsCommands(connection: dgtConnection, sessionLog: sessionLog)
            // File ▸ New Smart Tag… — the AX-reachable door (the sidebar's + is pointer-only).
            SmartTagCommands()
            // View ▸ Show View Options (⌘J); enabled only when a collection tab publishes the subject.
            CollectionViewOptionsCommands()
        }
        
        // D46′ — the evaluation graph. A separate group: macOS only tabs windows from the same group,
        // which this one must NOT do with the game windows. Keyed on `EvaluationGraphRequest`, not
        // `PersistentIdentifier` — `openWindow(value:)` routes by type, and a second group over the same
        // type makes existing calls unspecified.
        WindowGroup("Evaluation", for: EvaluationGraphRequest.self) { $request in
            EvaluationGraphWindow(request: request)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 720, height: 420)
        // Floating (Bera's call): the graph hovers in front — a popover dismisses on the first board click.
        .windowLevel(.floating)
        // D80′ — companions JOIN a full-screen space rather than claiming one. Scene-level, so the
        // role is set BEFORE placement; the AppKit configurator wrote it after, and never could work.
        .windowManagerRole(.associated)

        // D73′ — analysis as data, per-ply table. Fourth wrapper in the `openWindow(value:)` family.
        // Not floating, unlike the graph.
        WindowGroup("Analysis Data", for: AnalysisDataRequest.self) { $request in
            AnalysisDataWindow(request: request)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 460, height: 520)
        .windowManagerRole(.associated) // D80′

        // M10 Get Info — one group for all three subjects, so info windows tab with *each other*, never
        // behind a board. Not floating.
        WindowGroup("Info", for: GetInfoRequest.self) { $request in
            GetInfoWindow(request: request)
                .environment(dgtSession)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 460, height: 520)
        .windowManagerRole(.associated) // D80′

        // The analysis queue's window — a `Window`, not a `WindowGroup`: exactly one queue, opened by
        // `openWindow(id:)`, so the wrapper-type trap is sidestepped rather than paid.
        Window("Analysis", id: AnalysisQueueStatusWindowView.sceneID) {
            AnalysisQueueStatusWindowView()
                .environment(analysisQueue)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 520, height: 560)
        .defaultLaunchBehavior(.suppressed)
        .windowManagerRole(.associated) // D80′

        // View Options (⌘J) — a `Window` for the queue scene's reason: one panel, opened by id.
        Window("View Options", id: CollectionViewOptionsWindow.sceneID) {
            CollectionViewOptionsWindow()
                .environment(viewOptions)
        }
        .defaultSize(width: 340, height: 300)
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentMinSize)
        .windowLevel(.floating)
        .windowManagerRole(.associated) // D80′

        Settings {
            SettingsView()
                .environment(sleepInhibitor)
        }
        .modelContainer(sharedContainer)
    }
}
