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
    
    /// The app's one analysis queue. Constructed here because `init()` is the only place that runs
    /// exactly once - a scene receives values, not a tab's instance.
    @State private var analysisQueue: AnalysisQueueController
    
    // The three app-global DGT observables. Every registry must be injected into the WindowGroup or
    // a destination reading one traps at runtime - that was a real crash (previews injected, App didn't).
    @State private var dgtConnection: DGTConnection
    @State private var dgtSession: DGTLiveSession
    @State private var sessionLog: DGTSessionLog
    
    /// Sleep-inhibition token holder. Injected into **Settings only**, which owns the user gate;
    /// no destination reads it.
    @State private var sleepInhibitor: SleepInhibitor
    
    /// The board cues and their nine gates. Unlike `sleepInhibitor` this goes into **both** scenes:
    /// Settings binds the toggles, and `BoardDestination` wires each `Game`'s step cue.
    @State private var boardSounds: BoardSounds
    
    /// Which inspector sections are folded. Shared across tabs: collapsing Opening is a statement
    /// about openings, not about one window.
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
        
        // Mid-game vanish auto-reconnects. "Mid-game" is any game-bearing mode.
        connection.shouldAutoReconnect = { [weak session] in
            session?.liveGame != nil
        }
        
        // Every cue goes through one owning type, so Settings and playback cannot disagree about
        // a default: they are stated once, in `BoardSounds.init`.
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
        
        // Draft persistence: session owns when, store owns the file. Loading here is what turns a
        // relaunch into the Resume / Delete offer.
        let draftStore = LiveGameDraftStore()
        session.draftStore = draftStore
        
        // The archive door, wired before `loadPendingDraft()` so a resumed draft always has it.
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
        
        // Launch auto-connect in a Task so first render isn't held hostage to IOKit + handshake.
        // Guarded by `TestHost.isActive`: a real board must not feed the unit suite hardware events.
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
        // that happened to be open at quit. The two modifiers answer different questions - what
        // opens at launch vs. whether the previous set comes back - so disabling restoration alone
        // would launch to nothing. The draft sidecar already carries the session state worth
        // surviving a quit.
        .restorationBehavior(.disabled)
        // Commands are app-scoped, not per-tab. `GameNavigationCommands` is the scene half of
        // `.focusedSceneValue(\.activeGame, …)`.
        .commands {
            GameNavigationCommands()
            DiagnosticsCommands(connection: dgtConnection, sessionLog: sessionLog)
            // File ▸ New Smart Tag… - the AX-reachable door (the sidebar's + is pointer-only).
            SmartTagCommands()
            // View ▸ Show View Options (⌘J); enabled only when a collection tab publishes the subject.
            CollectionViewOptionsCommands()
            // View ▸ Show Session. Unconditional: a surface that used to appear by itself needs a
            // way to be asked for.
            SessionWindowCommands()
        }
        
        // The evaluation graph. A separate group because macOS only tabs windows from the same
        // group, which this one must NOT do with the game windows. Keyed on `EvaluationGraphRequest`,
        // not `PersistentIdentifier`: `openWindow(value:)` routes by *type*, and a second group over
        // a type already in use makes every existing untagged call unspecified.
        WindowGroup("Evaluation", for: EvaluationGraphRequest.self) { $request in
            EvaluationGraphWindow(request: request)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 720, height: 420)
        // Floating, deliberately: the graph hovers in front, where a popover would dismiss on the
        // first board click.
        .windowLevel(.floating)
        // Companions JOIN a full-screen space rather than claiming one. Scene-level, so the
        // role is set BEFORE placement; a configurator that wrote it after never could work.
        .windowManagerRole(.associated)
        // Session-only: this window describes a subject held by a board tab, and those do not come
        // back, so a restored graph would open beside nothing. Every companion scene below takes
        // this for the same reason, stated here once.
        .restorationBehavior(.disabled)
        
        // Analysis as data, per-ply table. Not floating, unlike the graph.
        WindowGroup("Analysis Data", for: AnalysisDataRequest.self) { $request in
            AnalysisDataWindow(request: request)
        }
        .modelContainer(sharedContainer)
        .defaultSize(width: 460, height: 520)
        .windowManagerRole(.associated)
        .restorationBehavior(.disabled) // companion - see the graph above
        
        // Get Info - one group for all three subjects, so info windows tab with *each other*, never
        // behind a board, and `value:` dedupes on the request so one subject has one window. Not
        // floating. The title names the affordance that opens it; a resolved request replaces it
        // with a per-subject title, so this is what the Window menu shows for an unresolved one.
        WindowGroup("Get Info", for: GetInfoRequest.self) { $request in
            GetInfoWindow(request: request)
                .environment(dgtSession)
        }
        .modelContainer(sharedContainer)
        // The tallest subject sets the default: the player's Performance tab stacks a monogram, a
        // four-column grid and a 160 pt chart. The others get a roomier window.
        .defaultSize(width: 520, height: 620)
        .windowManagerRole(.associated)
        .restorationBehavior(.disabled) // companion - see the graph above
        
        // The smart-tag editor. Not floating; sized by its own fixed frame.
        WindowGroup("Smart Tag", for: SmartTagEditorRequest.self) { $request in
            SmartTagEditorWindow(request: request)
        }
        .modelContainer(sharedContainer)
        // **No `.windowResizability` here or on any scene below, and the absence is the fix.** The
        // modifier is per-scene on paper and leaks to the main window in practice: a content-sized
        // main window re-sizes itself around the board on every content change and its green button
        // can only maximize. Each window's own frame bounds it instead.
        .windowManagerRole(.associated)
        .restorationBehavior(.disabled) // companion - see the graph above
        
        // A `Window`, not a `WindowGroup`: exactly one queue, opened by `openWindow(id:)`, so the
        // wrapper-type trap above is sidestepped rather than paid.
        Window("Analysis Queue", id: AnalysisQueueWindow.sceneID) {
            AnalysisQueueWindow()
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
        
        // Singleton: one session, one offer. Floating like its connection sibling below.
        Window("New Game", id: NewLiveGameWindow.sceneID) {
            NewLiveGameWindow()
                .environment(dgtSession)
        }
        .modelContainer(sharedContainer)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
        .windowLevel(.floating)
        .windowManagerRole(.associated)
        
        // Singleton for the queue scene's reason: one board, one connection, opened by id. Floating
        // because it is consulted over the board, not read as a tab.
        Window("Board Connection", id: DGTConnectionView.sceneID) {
            DGTConnectionView()
                .environment(dgtConnection)
        }
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
        .windowLevel(.floating)
        .windowManagerRole(.associated)
        
        // The session surface (D84′). Singleton, floating and associated like every other companion:
        // it is consulted *while* looking at the board, so it joins the board's full-screen space
        // rather than claiming one (D80′). The three DGT observables are injected here as they are
        // into the main group - a scene inherits no environment from the view that used to host it.
        Window("Session", id: SessionWindow.sceneID) {
            SessionWindow()
                .environment(dgtConnection)
                .environment(dgtSession)
                .environment(sessionLog)
        }
        .defaultSize(width: 320, height: 200)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
        .windowLevel(.floating)
        .windowManagerRole(.associated)
        
        // View Options (⌘J) - a `Window` for the queue scene's reason: one panel, opened by id.
        // Its `.contentMinSize` was removed twice: the second time, restoring it stopped the main
        // window height-resizing during live games, which is the resizability leak's signature.
        Window("View Options", id: CollectionViewOptionsWindow.sceneID) {
            CollectionViewOptionsWindow()
                .environment(viewOptions)
        }
        .defaultSize(width: 340, height: 300)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled) // see the Analysis window above
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
