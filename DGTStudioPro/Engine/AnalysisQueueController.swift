//
//  AnalysisQueueController.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 19/07/2026.
//

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
/// 1. **One analysis owner per tab.** This controller replaces the
///    per-inspector `GameAnalysisDriver` as the only thing that runs the
///    engine over Library games. The per-inspector design was rejected
///    for the batch era for the same reason `requestAnalysis` once
///    refused a second driver at the call site: two drivers racing over
///    one `PGN.evaluations` report a status neither's controls reflect.
///    Promoting the single driver here changes one behavior deliberately:
///    selecting a different game no longer cancels a running pass —
///    surviving browsing is the entire point of a queue. It also retires
///    the `pendingAnalysisID` one-shot relay: toolbar and context-menu
///    analyze only needed a routed request because the driver lived in a
///    view's `@State`; with the controller reachable directly, they
///    simply enqueue.
/// 2. **Owned by `TabState`.** A batch must survive Board↔Library
///    destination switches, and destination `@State` does not — the
///    exact class of state `TabState` exists to preserve. Per-tab like
///    everything on `TabState`: two tabs can still analyze the same game
///    simultaneously, exactly as two per-inspector drivers always could.
///    Unchanged, out of scope.
/// 3. **Continue on failure.** A game that fails (unparseable, deleted
///    mid-queue) records its outcome and the run advances — one corrupt
///    PGN must not strand the batch, mirroring the import loop's
///    never-abort rule. A missing engine binary therefore fails each
///    item with the same message rather than halting the run: noisier,
///    but honest, visible in the popover, and only reachable through a
///    developer-setup error (Engine_README.md).
/// 4. **Engine released at drain.** The subprocess stays warm across the
///    run — the driver reuses it game to game, paying the ~100ms UCI
///    handshake once per batch — and shuts down when the queue empties.
///    Tab close mid-run tears down via `shutdown()` from
///    `ContentView.onDisappear`; app quit closes the engine's stdin,
///    which a UCI engine treats as quit.
@Observable
@MainActor
internal final class AnalysisQueueController {
    
    // MARK: Static Constants
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "analysis"
    )
    
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
    
    /// Captured on each `enqueue`. One per tab in practice — the
    /// environment's main context — refreshed rather than injected at
    /// init because the controller is built by `TabState` before any
    /// view (and thus any environment) exists.
    private var modelContext: ModelContext?
    
    // MARK: View Conveniences
    
    /// Per-ply progress of the running game, `0...1`. Reads through the
    /// driver's observable status, so views tracking this re-render as
    /// the walk advances.
    internal var currentProgress: Double {
        if case .analyzing(let progress) = driver.status { return progress }
        return 0
    }
    
    // MARK: Enqueueing
    
    /// Adds `pgns` to the line (in the order given — callers pass display
    /// order) and starts the run if idle. Dedupe against the line and the
    /// running item happens in the pure queue; a single game is simply a
    /// batch of one.
    internal func enqueue(_ pgns: [PGN], modelContext: ModelContext) {
        self.modelContext = modelContext
        let accepted = queue.enqueue(pgns.map(\.persistentModelID))
        Self.logger.info(
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
    
    /// Clears the finished log — the drained popover's Dismiss, which
    /// also hides the toolbar's queue item once failures are acknowledged.
    internal func clearFinished() {
        queue.clearFinished()
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
    
    /// Tab teardown (window close): stand everything down and release the
    /// subprocess. Safe to call repeatedly — the driver's shutdown is
    /// re-entrant, and the run loop exits on the cancelled pass.
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
        else { return "—" }
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
            Self.logger.error("Run started without a model context; draining")
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
        Self.logger.info("Queue drained: \(self.queue.completedCount) finished")
    }
}
