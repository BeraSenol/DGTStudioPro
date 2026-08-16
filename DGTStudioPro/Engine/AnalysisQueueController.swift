import Foundation
import os
import SwiftData

/// The app's owner of batch analysis: transport around `AnalysisQueue`'s pure decisions.
/// Resolves ids to models, walks each through the one `GameAnalysisDriver`, records outcomes.
/// Decisions: (1) one driver, one engine - never two racing; (2) app-owned, not per-tab
/// (reversed 6 Aug 2026 - a scene receives values, not a tab's instance); (4) the subprocess is
/// released at drain; the next batch pays one fresh handshake.
@Observable
@MainActor
final class AnalysisQueueController {
    
    // MARK: Static Constants
    
    private static let logger = AppLog.logger(.analysis)
    
    // MARK: Queue State
    
    /// The pure decision core; views read it, every mutation routes through this controller.
    private(set) var queue = AnalysisQueue<PersistentIdentifier>()
    
    /// Running game's display name, resolved once at dequeue - a deleted-mid-pass model keeps its
    /// last known name instead of a lookup placeholder.
    private(set) var currentGameName: String?
    
    // MARK: Engine Transport
    
    private let driver = GameAnalysisDriver()
    private var runTask: Task<Void, Never>?
    
    /// Captured on each `enqueue` - the controller is built before any environment exists.
    private var modelContext: ModelContext?

    // MARK: Batch Bookkeeping

    /// *Searchable* ply count per queued game (book and satisfied plies excluded), captured
    /// at `enqueue` where the models are in hand: the estimate must not resolve waiting ids per tick.
    private var plyCounts: [PersistentIdentifier: Int] = [:]

    /// Batch start, or nil. The window's `TimelineView` derives elapsed from this - a controller
    /// publishing a per-second tick would re-render every observer.
    private(set) var batchStartedAt: Date?

    // MARK: Progress

    /// Plies finished, counting the running game's fraction. `Double`: rounding the numerator would
    /// make a long first game report zero rate for minutes.
    var pliesCompleted: Double {
        let finished = queue.finished.reduce(into: 0.0) { total, record in
            total += Double(plyCounts[record.id] ?? 0)
        }
        guard let current = queue.current else { return finished }
        return finished + Double(plyCounts[current] ?? 0) * currentProgress
    }

    /// Plies still to search: waiting plus the running game's remainder.
    var pliesRemaining: Int {
        let waiting = queue.waiting.reduce(into: 0) { total, id in
            total += plyCounts[id] ?? 0
        }
        guard let current = queue.current else { return waiting }
        let total = Double(plyCounts[current] ?? 0)
        return waiting + Int((total * (1 - currentProgress)).rounded())
    }

    /// Ply count for a queued id, or nil. Read-only by design - only `enqueue` writes, or the
    /// estimate would be denominated in two different things.
    func plyCount(for id: PersistentIdentifier) -> Int? {
        plyCounts[id]
    }

    /// The current search, forwarded - the driver is `private` precisely so the transport has one
    /// door; a window holding it could call `stop()` behind the queue's back.
    var currentSearch: GameAnalysisDriver.Search? { driver.search }

    /// Seconds remaining, or nil before a rate exists; arithmetic lives in `BatchProgressEstimate`.
    var secondsRemaining: TimeInterval? {
        guard let batchStartedAt else { return nil }
        return BatchProgressEstimate.secondsRemaining(
            pliesCompleted: pliesCompleted,
            pliesRemaining: pliesRemaining,
            elapsed: Date.now.timeIntervalSince(batchStartedAt)
        )
    }
    
    // MARK: View Conveniences
    
    /// Per-ply progress of the running game, `0...1`; observable, so views re-render as the walk advances.
    var currentProgress: Double {
        if case .analyzing(let progress) = driver.status { return progress }
        return 0
    }

    /// The game on the engine now - the currency `AnalysisGlyph.state` takes, published through
    /// `analysisRunningGameID`. Deliberately not observing progress: leaves asking *whether* must
    /// not re-render on *how far*.
    var runningID: PersistentIdentifier? { queue.current }
    
    // MARK: Enqueueing
    
    /// Enqueue in the order given (callers pass display order); dedupe is the pure queue's. A single
    /// game is a batch of one.
    func enqueue(_ pgns: [PGN], modelContext: ModelContext) {
        self.modelContext = modelContext
        // Before the enqueue: `wasIdle` distinguishes a fresh batch from an extension, and extending
        // must not restart the clock.
        let wasIdle = !queue.isActive
        for pgn in pgns {
            // The estimate is denominated in *searchable* plies - the plan the driver will
            // build - or a skipped book registers as impossible speed and rots the projection.
            // An unclassified game estimates full-length; its pass classifies, and any later
            // enqueue tightens.
            plyCounts[pgn.persistentModelID] = AnalysisPlan.plan(
                moveCount: pgn.moves.count,
                evaluations: pgn.evaluations,
                depths: pgn.analysisDepths,
                bookPlies: pgn.ecoDepth ?? 0,
                targetDepth: EngineConfiguration.current.depth
            ).searchable.count
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
    
    /// Stops the running game's pass (recorded `.cancelled`, evaluations kept); the run advances.
    func skipCurrent() {
        driver.stop()
    }
    
    /// Removes a waiting game; the running one is `skipCurrent()`'s job.
    func removeWaiting(_ id: PersistentIdentifier) {
        queue.removeWaiting(id)
    }
    
    /// Empties the line and stops the pass; the loop drains and releases the engine (decision 4).
    func stopAll() {
        queue.clearWaiting()
        driver.stop()
    }
    
    /// Clears the finished log (the window's Dismiss) and the batch bookkeeping with it.
    func clearFinished() {
        queue.clearFinished()
        plyCounts.removeAll()
        batchStartedAt = nil
    }
    
    /// Library deletion hook - call **before** the store delete: `driver.stop()` sets the walk's
    /// cancellation flag synchronously, so the model is never written after the delete.
    func gameWasDeleted(_ id: PersistentIdentifier) {
        queue.removeWaiting(id)
        // `status(of:)` answers `.running` by this same comparison.
        if queue.current == id {
            driver.stop()
        }
    }
    
    /// Stand everything down and release the subprocess; re-entrant. **Test-only by decision** -
    /// teardown, not a feature door: suites must never leave Stockfish running.
    func shutdown() async {
        queue.clearWaiting()
        runTask?.cancel()
        await driver.shutdown()
    }
    
    // MARK: Status
    
    /// The queue's view of one game - what the inspector's control row switches on.
    func status(
        of id: PersistentIdentifier
    ) -> AnalysisQueue<PersistentIdentifier>.ItemStatus {
        queue.status(of: id)
    }
    
    /// Display name for the popover; the placeholder for anything no longer resolvable.
    func displayName(for id: PersistentIdentifier) -> String {
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
            // Re-check the line after clearing the task: an `enqueue` landing during the drain's shutdown
            // grace saw a non-nil `runTask` and was refused - this restart is its retry. Pinned.
            self?.startRunIfNeeded()
        }
    }
    
    private func run() async {
        guard let modelContext else {
            // Unreachable by construction (`enqueue` sets the context first) - but a drain beats a wedge.
            Self.logger?.error("Run started without a model context; draining")
            while queue.startNext() != nil {
                queue.finishCurrent(.failed(message: "Internal error: no model context."))
            }
            return
        }
        
        while !Task.isCancelled, let id = queue.startNext() {
            // Blessed id→model resolution + tombstone guard: deleted-while-waiting records failed rather
            // than crashing the walk.
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
                // `.idle` is the driver's landing state after `stop()`; `.analyzing` is unreachable post-await,
                // mapped defensively.
                queue.finishCurrent(.cancelled)
            }
            currentGameName = nil
        }
        
        // Teardown can cancel between `startNext` and the walk - don't leave a phantom running item.
        queue.finishCurrent(.cancelled)
        currentGameName = nil
        
        // Decision 4: release the subprocess at drain; nothing idles in Activity Monitor.
        await driver.shutdown()
        Self.logger?.info("Queue drained: \(self.queue.completedCount) finished")
    }
}
