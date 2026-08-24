import AppKit
import SwiftData
import SwiftUI

@main
@MainActor
struct DGTStudioProApp: App {
    
    /// Shared `ModelContainer`: tabs share one so `PersistentIdentifier`s round-trip.
    private let sharedContainer: ModelContainer = {
        do {
            // All three listed explicitly - load-bearing: `SmartTag` has no relationships, so schema
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

    /// The app's one analysis queue (app-global since 6 Aug - a scene receives values, not a tab's
    /// instance). Constructed here; `init()` is the only place that runs exactly once.
    @State private var analysisQueue: AnalysisQueueController
    
    // The three app-global DGT observables. Every registry must be injected into the WindowGroup or
    // a destination reading one traps at runtime - that was a real crash (previews injected, App didn't).
    @State private var dgtConnection: DGTConnection
    @State private var dgtSession: DGTLiveSession
    @State private var sessionLog: DGTSessionLog
    
    /// Sleep-inhibition token holder. Injected into **Settings only** (it owns the user
    /// gate); no destination reads it.
    @State private var sleepInhibitor: SleepInhibitor

    /// The board cues and their four gates. Unlike `sleepInhibitor` this goes into **both**
    /// scenes: Settings binds the toggles, and `BoardDestination` wires each `Game`'s step cue.
    @State private var boardSounds: BoardSounds

    /// Which inspector sections are folded. Injected into the WindowGroup - every inspector
    /// reads it, shared across tabs: collapsing Opening is a statement about openings, not a window.
    @State private var inspectorCollapse = InspectorSectionCollapse(defaults: .standard)

    /// View Options subject - `inspectorCollapse`'s arrangement, for its reasons.
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
        
        // Board identity stamped at game start. Strong capture, deliberately: session → connection
        // is the only strong edge (the connection's hooks capture the session weakly), so no cycle.
        session.boardIdentity = {
            connection.boardInfo.identityTag
        }

        // Session suspects, connection asks the hardware; recovery only after the dump fails too.
        session.requestBoardResync = {
            connection.requestBoardResync()
        }

        // M7.3 - mid-game vanish auto-reconnects. "Mid-game" is any game-bearing mode.
        connection.shouldAutoReconnect = { [weak session] in
            session?.liveGame != nil
        }
        
        // Every cue now goes through one owning type. The `onDesync` closure below used to re-read
        // `UserDefaults` and state its own `?? true` - the twin `StorageKeys` documented - and used
        // to ring `NSSound.beep()`. Both are gone: defaults are stated once, in `BoardSounds.init`,
        // and Settings and playback cannot disagree about them.
        let sounds = BoardSounds()

        session.onMoveCommitted = { cue in
            sounds.play(cue)
        }

        // Fired once per desync *entry*, not per scan - the session owns that edge, which is what
        // keeps a board left in a wrong position from cueing repeatedly.
        session.onDesync = {
            sounds.play(.illegal)
        }

        session.onGameStarted = {
            sounds.play(.gameStart)
        }

        // Deliberately not `onGameFinished`: that one archives and can throw, and a cue that fires
        // only when a write succeeds is a cue that reports the wrong thing. This is the game
        // reaching a result, which is what the reader is listening for.
        session.onGameEnded = {
            sounds.play(.gameEnd)
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
        
        // The inhibition observer, wired once: the content closure runs per tab, and two
        // tabs must not race one token.
        let analysis = AnalysisQueueController()
        let inhibitor = SleepInhibitor()
        inhibitor.observe(session: session, connection: connection, analysis: analysis)
        
        // M7.2 - launch auto-connect in a Task so first render isn't held hostage to IOKit + handshake.
        // Guarded by `TestHost.isActive`: a real board must not feed the unit suite hardware events (hermetic host).
        if !TestHost.isActive {
            Task { await connection.autoConnectAtLaunch() }
        }
        
        _dgtConnection = State(initialValue: connection)
        _dgtSession = State(initialValue: session)
        _sessionLog = State(initialValue: log)
        _sleepInhibitor = State(initialValue: inhibitor)
        _analysisQueue = State(initialValue: analysis)
        _boardSounds = State(initialValue: sounds)
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
                .environment(boardSounds)
        }
        .modelContainer(sharedContainer)
        .defaultLaunchBehavior(.presented)
        // Game tabs are session-only: a relaunch opens one fresh Library window rather than the set
        // that happened to be open at quit. `.defaultLaunchBehavior(.presented)` above is what still
        // supplies that one window - the two modifiers answer different questions (what opens at
        // launch vs. whether the previous set comes back), so disabling restoration alone would
        // launch to nothing. Reviewing a game is a thing you start, not a thing you resume, and the
        // draft sidecar already carries the only session state worth surviving a quit.
        .restorationBehavior(.disabled)
        // M8.1 Game menu (←/→/Home/End) - the scene half of `.focusedSceneValue(\.activeGame, …)`.
        // Diagnostics rides in the same block; commands are app-scoped, not per-tab.
        .commands {
            GameNavigationCommands()
            DiagnosticsCommands(connection: dgtConnection, sessionLog: sessionLog)
            // File ▸ New Smart Tag… - the AX-reachable door (the sidebar's + is pointer-only).
            SmartTagCommands()
            // View ▸ Show View Options (⌘J); enabled only when a collection tab publishes the subject.
            CollectionViewOptionsCommands()
            // View ▸ Show Session - the door to the surface that stopped being an overlay (D84′).
            // Unconditional: a panel that used to appear by itself needs a way to be asked for.
            SessionWindowCommands()
        }
        
        // The evaluation graph. A separate group: macOS only tabs windows from the same group,
        // which this one must NOT do with the game windows. Keyed on `EvaluationGraphRequest`, not
        // `PersistentIdentifier` - `openWindow(value:)` routes by type, and a second group over the same
        // type makes existing calls unspecified.
        WindowGroup("Evaluation", for: EvaluationGraphRequest.self) { $request in
            EvaluationGraphWindow(request: request)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 720, height: 420)
        // Floating (Bera's call): the graph hovers in front - a popover dismisses on the first board click.
        .windowLevel(.floating)
        // Companions JOIN a full-screen space rather than claiming one. Scene-level, so the
        // role is set BEFORE placement; the AppKit configurator wrote it after, and never could work.
        .windowManagerRole(.associated)
        // Session-only, and the companions' reason is the stronger one: this window describes a
        // subject held by a board tab, and those no longer come back. A restored graph would open
        // beside nothing - worse than the game tabs' case, which at least restored something real.
        // The three companion groups and the two singleton windows below all take this for the
        // same reason; it is stated here once rather than five times.
        .restorationBehavior(.disabled)

        // Analysis as data, per-ply table. Fourth wrapper in the `openWindow(value:)` family.
        // Not floating, unlike the graph.
        WindowGroup("Analysis Data", for: AnalysisDataRequest.self) { $request in
            AnalysisDataWindow(request: request)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 460, height: 520)
        .windowManagerRole(.associated)
        .restorationBehavior(.disabled) // companion - see the graph above

        // M10 Get Info - one group for all three subjects, so info windows tab with *each other*, never
        // behind a board. Not floating.
        //
        // **It absorbed the Matchup group on 18 Aug 2026.** That group was a second window over a
        // subject this one already had: the double-click opened a player's profile, ⌘I opened the
        // same player's rename, and the two could not see each other's writes. Both doors now open
        // this group, and `value:` dedupes on the request, so one player can only ever have one
        // window. The player subject grew the Profile and Matchup tabs to take the content.
        // Titled "Get Info", after the menu item and the row-menu label that open it (21 Aug 2026).
        // The per-subject title below replaces this for a resolved request; this is what the Window
        // menu and an unresolved window show, and it should name the affordance the reader used.
        WindowGroup("Get Info", for: GetInfoRequest.self) { $request in
            GetInfoWindow(request: request)
                .environment(dgtSession)
        }
        .modelContainer(sharedContainer)
        // Taller than the 460 × 520 the game subject wanted alone: the player's Profile tab stacks a
        // monogram, a four-column grid and a 160 pt chart, and the old Matchup window's 460 × 340
        // cannot hold it. The tallest subject sets the default; the others get a roomier window.
        .defaultSize(width: 520, height: 620)
        .windowManagerRole(.associated)
        .restorationBehavior(.disabled) // companion - see the graph above

        // The smart-tag editor as its own window (16 Aug 2026; was ContentView's sheet). Sixth
        // wrapper in the `openWindow(value:)` family. Not floating; sized by its own fixed frame.
        WindowGroup("Smart Tag", for: SmartTagEditorRequest.self) { $request in
            SmartTagEditorWindow(request: request)
        }
        .modelContainer(sharedContainer)
        // No `.windowResizability(.contentSize)` here or on the two dialogs below, and the
        // absence is the fix (16 Aug 2026): the modifier is per-scene on paper and leaks to the
        // main window in practice - a content-sized main window re-sizes itself around the board
        // on every content change and its green button can only maximize, which is exactly the
        // "everything zooms and full screen is gone" report. The windows' own frames already
        // bound them; automatic resizability derives its limits from content.
        .windowManagerRole(.associated)
        .restorationBehavior(.disabled) // companion - see the graph above

        // The analysis queue's window - a `Window`, not a `WindowGroup`: exactly one queue, opened by
        // `openWindow(id:)`, so the wrapper-type trap is sidestepped rather than paid.
        // **"Analysis Queue", not "Analysis"** (21 Aug 2026): the Window menu listed this beside
        // "Analysis - Kasparov vs Karpov" and left the reader to guess which was the queue. Its own
        // help text, its type name and its identifier (`analysis.queue.window`) all already said
        // queue; the window title was the one place that didn't. The unqualified name belongs to
        // nothing when everything else qualifies.
        Window("Analysis Queue", id: AnalysisQueueStatusWindowView.sceneID) {
            AnalysisQueueStatusWindowView()
                .environment(analysisQueue)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 520, height: 560)
        // `.suppressed` is not restoration policy, which is the trap worth naming: it says this
        // window does not open *by default* at launch, and says nothing about one left open at
        // quit. Both singletons carried it and both came back anyway.
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .windowManagerRole(.associated)

        // The New Game dialog (16 Aug 2026; was BoardDestination's sheet) - singleton: one
        // session, one offer. Floating like its connection sibling below.
        Window("New Game", id: NewLiveGameWindow.sceneID) {
            NewLiveGameWindow()
                .environment(dgtSession)
        }
        .modelContainer(sharedContainer)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
        .windowLevel(.floating)
        .windowManagerRole(.associated)

        // The board connection dialog (16 Aug 2026; was BoardDestination's sheet) - a singleton
        // `Window` for the queue scene's reason: one board, one connection, opened by id.
        // Floating like View Options: a companion consulted over the board, not a tab.
        Window("Board Connection", id: DGTConnectionView.sceneID) {
            DGTConnectionView()
                .environment(dgtConnection)
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
        .windowLevel(.floating)
        .windowManagerRole(.associated)

        // The session surface (18 Aug 2026, D84′; was BoardDestination's `.overlay` over the
        // board's top edge). A singleton `Window` for the connection scene's reason: one session,
        // one surface, opened by id. Floating and associated like every other companion - it is
        // consulted *while* looking at the board, so it must join the board's full-screen space
        // rather than claim one (D80′).
        //
        // The three DGT observables are injected here as they are into the main group: a scene
        // gets no environment from the destination that used to host this view.
        Window("Session", id: SessionWindow.sceneID) {
            SessionWindow()
                .environment(dgtConnection)
                .environment(dgtSession)
                .environment(sessionLog)
        }
        .defaultSize(width: 320, height: 200)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
        // NO `.windowResizability` - the 17 Aug rule, and this scene has the strongest claim to
        // want it: content-derived limits on a companion are what stopped the main window
        // height-resizing during live games. The frame in `SessionWindow` bounds it instead.
        .windowLevel(.floating)
        .windowManagerRole(.associated)

        // View Options (⌘J) - a `Window` for the queue scene's reason: one panel, opened by id.
        Window("View Options", id: CollectionViewOptionsWindow.sceneID) {
            CollectionViewOptionsWindow()
                .environment(viewOptions)
        }
        .defaultSize(width: 340, height: 300)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
        // NO `.windowResizability` here - removed twice, kept out for good (17 Aug 2026).
        // The 16 Aug purge dropped `.contentSize` from three dialog scenes because scene
        // resizability leaks to the main window in practice; this `.contentMinSize` survived
        // that purge, was exonerated for the *toolbar* fault by the strip test, got restored -
        // and then the main window stopped height-resizing during live games, which is the
        // leak's signature (content min-size enforced on a window this scene never owned).
        // The panel's own frame bounds it; automatic resizability derives its limits from
        // content.
        .windowLevel(.floating)
        .windowManagerRole(.associated)

        Settings {
            SettingsView()
                .environment(sleepInhibitor)
                .environment(boardSounds)
        }
        .modelContainer(sharedContainer)
    }
}
