import Foundation
import os
import SwiftData

/// Per-tab owner of batch engine analysis: the transport around
/// `AnalysisQueue`'s pure decisions. Resolves queued
/// `PersistentIdentifier`s to models, walks each game through the one
/// `GameAnalysisDriver`, and records outcomes back into the queue.
///
/// Ownership decisions (numbered so the views can cite them):
///
/// 1. **One analysis owner**, replacing the per-inspector
///    `GameAnalysisDriver`: two drivers racing over one `PGN.evaluations`
///    report a status neither's controls reflect. One behaviour changed
///    deliberately — selecting a different game no longer cancels a running
///    pass, since surviving browsing is the point of a queue.
/// 2. **Owned by the app, not by a tab** — reversed 6 Aug 2026, and the
///    original reasoning is kept because half of it still holds. It read:
///    *"Owned by `TabState`. A batch must survive Board↔Library switches and
///    destination `@State` does not… Per-tab, so two tabs can analyze the same
///    game at once, exactly as two per-inspector drivers always could."* The
///    first sentence is why it could not be destination state and is untouched.
///    The second justified per-tab by *precedent* rather than by need, and the
///    precedent was a bug being preserved: two tabs meant two Stockfish
///    subprocesses, each configured `Hash 1024` and `Threads 12`, contending
///    for one twelve-core Mac and two gigabytes of hash table. One person, one
///    Mac (the standing input) cannot watch two batches, and the app has one
///    engine binary and one `EngineConfiguration`.
///
///    The proximate cause was the queue window: a scene cannot be handed a
///    reference to a particular tab's object, and `TabState` has no identity to
///    resolve one by. The alternative was minting a tab id and an app-global
///    registry to look controllers up in — machinery whose only purpose would
///    have been to preserve concurrency that hurts. Owned by
///    `DGTStudioProApp` and injected into the `WindowGroup` like
///    `OpenGamesRegistry`; `TabState` no longer holds it.
///
///    **Named consequence:** a batch no longer dies with the tab that started
///    it. Closing a Library tab mid-run used to stand the queue down (decision
///    4's teardown hook, removed from `ContentView.onDisappear` in the same
///    change); now the run continues and the window can still be opened over
///    it. That is the correct reading of an app-global queue and it is a
///    behaviour change, not a side effect.
/// 3. **Continue on failure.** A game that fails (unparseable, deleted
///    mid-queue) records its outcome and the run advances — one corrupt PGN
///    must not strand the batch, the import loop's never-abort rule. A missing
///    engine binary therefore fails each item with the same message rather than
///    halting: noisier but honest, visible in the popover, and reachable only
///    through a developer-setup error (Engine_README.md).
/// 4. **Engine released at drain.** The subprocess stays warm across the run,
///    paying the ~100 ms UCI handshake once per batch, and shuts down when the
///    queue empties. App quit closes stdin, which a UCI engine treats as quit.
///    (Tab close tore it down too, from `ContentView.onDisappear`, until
///    decision 2 went app-global on 6 Aug 2026 — a per-tab teardown hook on an
///    app-global object means closing any window kills a batch started from
///    another, so the hook went with the ownership.)
@Observable
@MainActor
internal final class AnalysisQueueController {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.analysis)
    
    // MARK: Queue State
    
    /// The pure decision core. Views read it directly for counts,
    /// membership, and outcomes; every mutation routes through this
    /// controller so line and engine can never disagree.
    internal private(set) var queue = AnalysisQueue<PersistentIdentifier>()
    
    /// Display name of the game currently on the engine, resolved once at
    /// dequeue for the toolbar popover — a deleted-mid-pass model keeps
    /// its last known name on screen instead of a lookup placeholder.
    internal private(set) var currentGameName: String?
    
    // MARK: Engine Transport
    
    private let driver = GameAnalysisDriver()
    private var runTask: Task<Void, Never>?
    
    /// Captured on each `enqueue` — the environment's main context,
    /// refreshed rather than injected at init because the controller is
    /// built by `DGTStudioProApp` before any view (and thus any
    /// environment) exists.
    private var modelContext: ModelContext?

    // MARK: Batch Bookkeeping

    /// Ply count per queued game, captured at `enqueue` where the models are
    /// already in hand.
    ///
    /// **Recorded rather than looked up**, because the alternative is resolving
    /// every waiting id back to a `PGN` on every render of the window — a
    /// fetch-per-row on a surface that redraws once a second from its own
    /// `TimelineView`. It is also more correct: a game deleted mid-batch still
    /// contributes the work already done for it, where a lookup would return
    /// nothing and make the estimate jump.
    ///
    /// Cleared with the finished log rather than at drain, so a drained batch's
    /// window can still show what it did.
    private var plyCounts: [PersistentIdentifier: Int] = [:]

    /// When the current batch began, or nil when nothing has run since the log
    /// was last cleared. The window's `TimelineView` derives elapsed from this
    /// rather than the controller publishing a per-second tick — a clock that
    /// invalidates an `@Observable` once a second would re-render every
    /// observer, and the only one that wants the second hand is the window.
    internal private(set) var batchStartedAt: Date?

    // MARK: Progress

    /// Plies finished so far in this batch, counting the running game's
    /// fractional progress. `Double` because the running game contributes a
    /// fraction — the estimator's whole input is a rate, and rounding the
    /// numerator would make a long first game report zero rate for minutes.
    internal var pliesCompleted: Double {
        let finished = queue.finished.reduce(into: 0.0) { total, record in
            total += Double(plyCounts[record.id] ?? 0)
        }
        guard let current = queue.current else { return finished }
        return finished + Double(plyCounts[current] ?? 0) * currentProgress
    }

    /// Plies still to search: what is waiting, plus the unfinished remainder of
    /// the running game.
    internal var pliesRemaining: Int {
        let waiting = queue.waiting.reduce(into: 0) { total, id in
            total += plyCounts[id] ?? 0
        }
        guard let current = queue.current else { return waiting }
        let total = Double(plyCounts[current] ?? 0)
        return waiting + Int((total * (1 - currentProgress)).rounded())
    }

    /// How many plies a queued game holds, or nil for one enqueued before this
    /// bookkeeping existed or already cleared. Read-only by design: the counts
    /// are captured at `enqueue` and nothing else may write them, or the
    /// estimate would be denominated in two different things.
    internal func plyCount(for id: PersistentIdentifier) -> Int? {
        plyCounts[id]
    }

    /// What the engine is searching right now, or nil between plies and between
    /// games. Forwarded from the driver rather than the window reaching past
    /// this controller: the driver is `private` here precisely so the queue's
    /// transport has one door, and a window holding it could call `stop()`
    /// behind the queue's back — the two-drivers-racing failure decision 1
    /// exists to prevent, one layer up.
    internal var currentSearch: GameAnalysisDriver.Search? { driver.search }

    /// Seconds still to run, or nil before a rate can be observed. The
    /// arithmetic and its caveats live in `BatchProgressEstimate`.
    internal var secondsRemaining: TimeInterval? {
        guard let batchStartedAt else { return nil }
        return BatchProgressEstimate.secondsRemaining(
            pliesCompleted: pliesCompleted,
            pliesRemaining: pliesRemaining,
            elapsed: Date.now.timeIntervalSince(batchStartedAt)
        )
    }
    
    // MARK: View Conveniences
    
    /// Per-ply progress of the running game, `0...1`. Reads through the
    /// driver's observable status, so views tracking this re-render as
    /// the walk advances.
    internal var currentProgress: Double {
        if case .analyzing(let progress) = driver.status { return progress }
        return 0
    }

    /// The game on the engine right now, or nil — the currency
    /// `AnalysisGlyph.state(of:runningID:)` takes, published to the Library's
    /// leaves through `EnvironmentValues.analysisRunningGameID`.
    ///
    /// An **id** rather than a `PGN`, and that turned out to matter: the
    /// Library toolbar's Analyze button resolved this back into a model through
    /// the filtered list, which the Not Analyzed chip emptied out from under it
    /// mid-batch, dropping the glyph to red-x while the engine worked on. An
    /// identifier compares against an id set without asking anything about what
    /// is on screen. That button was removed by request before the id-based fix
    /// had a second run; the hazard is recorded at
    /// `AnalysisGlyph.state(of:runningID:)` for whoever writes the next
    /// aggregate caller.
    ///
    /// `queue.current` directly rather than `status(of:) == .running`, and the
    /// difference is not style: this is read at every glyph site on every body
    /// pass, while `status(of:)` scans `waiting` and then `finished` to rule
    /// out the other cases before it can answer. `gameWasDeleted` already makes
    /// the same comparison for the same reason, and says so.
    ///
    /// Deliberately **not** `currentProgress`'s neighbour in what it observes:
    /// this changes once per game, that changes once per ply. A view wanting to
    /// know *whether* work is happening must not be re-rendered by *how far
    /// along* it is — which is the whole reason the environment carries this id
    /// rather than the controller (see `EnvironmentValues.analysisRunningGameID`).
    internal var runningID: PersistentIdentifier? { queue.current }
    
    // MARK: Enqueueing
    
    /// Adds `pgns` to the line (in the order given — callers pass display
    /// order) and starts the run if idle. Dedupe against the line and the
    /// running item happens in the pure queue; a single game is simply a
    /// batch of one.
    internal func enqueue(_ pgns: [PGN], modelContext: ModelContext) {
        self.modelContext = modelContext
        // Before the enqueue, because `AnalysisQueue.enqueue` clears the
        // finished log on a fresh batch and `wasIdle` is what tells this apart
        // from an enqueue that *extends* a live run. Extending must not restart
        // the clock — the elapsed figure is about the batch, and a run that
        // grew is still the same run.
        let wasIdle = !queue.isActive
        for pgn in pgns {
            plyCounts[pgn.persistentModelID] = pgn.moves.count
        }
        let accepted = queue.enqueue(pgns.map(\.persistentModelID))
        if wasIdle, accepted > 0 {
            batchStartedAt = .now
        }
        Self.logger?.info(
            "Enqueued \(accepted)/\(pgns.count) game(s); \(self.queue.remainingCount) in the run"
        )
        startRunIfNeeded()
    }
    
    // MARK: Controls
    
    /// Stops the running game's pass. Its evaluations so far stay in the
    /// PGN (recorded as `.cancelled`) and the run advances to the next
    /// game in line.
    internal func skipCurrent() {
        driver.stop()
    }
    
    /// Removes a waiting game from the line. No effect on the running
    /// game — that is `skipCurrent()`'s job.
    internal func removeWaiting(_ id: PersistentIdentifier) {
        queue.removeWaiting(id)
    }
    
    /// Empties the line and stops the running pass; the run loop then
    /// drains naturally and releases the engine (decision 4).
    internal func stopAll() {
        queue.clearWaiting()
        driver.stop()
    }
    
    /// Clears the finished log — the window's Dismiss, which also hides the
    /// toolbar's queue item once failures are acknowledged.
    ///
    /// Takes the batch bookkeeping with it: acknowledging a drained run is the
    /// point at which its elapsed time and ply census stop describing anything.
    /// Leaving them would make the *next* batch's window open with the last
    /// one's clock still counting.
    internal func clearFinished() {
        queue.clearFinished()
        plyCounts.removeAll()
        batchStartedAt = nil
    }
    
    /// Library deletion hook. Callers invoke this **before** the store
    /// delete: `driver.stop()` sets the walk's cancellation flag
    /// synchronously, and the walk checks that flag on every resume
    /// before touching the PGN — so the model is never written after the
    /// store tears it down. A deleted waiting game just leaves the line.
    /// (The run loop's tombstone guard would catch a missed call; this
    /// hook skips the wasted engine work.)
    internal func gameWasDeleted(_ id: PersistentIdentifier) {
        queue.removeWaiting(id)
        // `status(of:)` answers `.running` by this same comparison, then
        // scans `waiting` and `finished` to rule out the other cases.
        if queue.current == id {
            driver.stop()
        }
    }
    
    /// Stand everything down and release the subprocess. Safe to call
    /// repeatedly — the driver's shutdown is re-entrant, and the run loop exits
    /// on the cancelled pass.
    ///
    /// **Test-only by decision since 6 Aug 2026**, and named as such rather
    /// than left to look alive. Its production caller was
    /// `ContentView.onDisappear`, which stood the queue down on tab close; that
    /// hook went with decision 2's move to app-global ownership, because a
    /// per-window teardown of an app-global object lets closing any window kill
    /// a batch another window started. Nothing replaced it: decision 4 already
    /// releases the subprocess at drain, and app quit closes stdin, which a UCI
    /// engine treats as quit.
    ///
    /// Kept rather than deleted, which is the opposite of the call D52′ made
    /// for `merge` — and the difference is that this is *teardown*, not a
    /// feature. `AnalysisQueueControllerTests` ends its live-engine race with
    /// it so a suite never leaves Stockfish running, and an app-termination
    /// hook is one line away if quitting mid-batch ever needs to be graceful
    /// rather than abrupt.
    internal func shutdown() async {
        queue.clearWaiting()
        runTask?.cancel()
        await driver.shutdown()
    }
    
    // MARK: Status
    
    /// The queue's view of one game — what the inspector's control row
    /// switches on.
    internal func status(
        of id: PersistentIdentifier
    ) -> AnalysisQueue<PersistentIdentifier>.ItemStatus {
        queue.status(of: id)
    }
    
    /// Resolves a queued id to its display name for the popover; an
    /// em dash for anything no longer resolvable (deleted mid-queue).
    internal func displayName(for id: PersistentIdentifier) -> String {
        guard let modelContext,
              let pgn = modelContext.model(for: id) as? PGN,
              !pgn.isDeleted
        else { return RosterSummary.displayUnknown }
        return pgn.name
    }
    
    // MARK: Run Loop
    
    private func startRunIfNeeded() {
        guard runTask == nil, queue.isActive else { return }
        runTask = Task { @MainActor [weak self] in
            await self?.run()
            self?.runTask = nil
            // Re-check the line after clearing the task: an `enqueue`
            // landing during the drain's `driver.shutdown()` grace
            // (a ≥500 ms suspension inside `run()`) saw a non-nil
            // `runTask` in the guard above and was refused a start —
            // pre-fix that item sat "#1 in line" forever (M1 item 1).
            // A teardown-emptied queue makes this a no-op, and a
            // grace-window batch pays decision 4's fresh handshake
            // exactly as any post-drain batch does. Pinned by
            // `AnalysisQueueControllerTests`.
            self?.startRunIfNeeded()
        }
    }
    
    private func run() async {
        guard let modelContext else {
            // Unreachable by construction — `enqueue` sets the context
            // before starting the run — but a drain beats a wedge if the
            // wiring ever drifts.
            Self.logger?.error("Run started without a model context; draining")
            while queue.startNext() != nil {
                queue.finishCurrent(.failed(message: "Internal error: no model context."))
            }
            return
        }
        
        while !Task.isCancelled, let id = queue.startNext() {
            // Blessed id→model resolution (see BoardDestination), plus the
            // tombstone guard: a game deleted while waiting resolves here
            // and is recorded as failed rather than crashing the walk.
            guard let pgn = modelContext.model(for: id) as? PGN, !pgn.isDeleted else {
                queue.finishCurrent(.failed(message: "Game no longer exists."))
                continue
            }
            
            currentGameName = pgn.name
            let final = await driver.analyze(pgn: pgn, modelContext: modelContext)
            
            switch final {
            case .done:
                queue.finishCurrent(.done)
            case .failed(let message):
                queue.finishCurrent(.failed(message: message))
            case .idle, .analyzing:
                // `.idle` is the driver's landing state after `stop()`;
                // `.analyzing` is unreachable post-await and mapped
                // defensively rather than crashed on.
                queue.finishCurrent(.cancelled)
            }
            currentGameName = nil
        }
        
        // Teardown can cancel between `startNext` and the walk — don't leave
        // a phantom "running" item in the log. `finishCurrent` no-ops with
        // nothing running, which is what the guard here was re-asking.
        queue.finishCurrent(.cancelled)
        currentGameName = nil
        
        // Decision 4: release the subprocess at drain. The next batch
        // pays one fresh handshake; nothing idles in Activity Monitor.
        await driver.shutdown()
        Self.logger?.info("Queue drained: \(self.queue.completedCount) finished")
    }
}
