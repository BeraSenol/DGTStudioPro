//
//  AnalysisQueue.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 19/07/2026.
//

/// Pure decisions behind batch engine analysis — ordering, dedupe,
/// advancement, and outcome bookkeeping — extracted from
/// `AnalysisQueueController` for the same reason `DGTAutoConnectPolicy`
/// was extracted from `DGTConnection`: the interesting choices are
/// unit-testable without SwiftData or an engine subprocess. The controller
/// keeps only the transport (model resolution, the Stockfish walk,
/// run-task plumbing) around these calls.
///
/// This is also the M9 answer for the `GameAnalysisDriver` audit line:
/// the analysis pipeline finally grew branching worth owning when it grew
/// a queue, and this type is where that branching lives — pure, so the
/// driver and controller stay thin transport and take the waiver.
///
/// Generic over the id rather than bound to `PersistentIdentifier` so the
/// test suite runs hermetically on plain strings; the controller
/// instantiates `AnalysisQueue<PersistentIdentifier>`.
///
/// Semantics worth stating (each is pinned by a test):
/// - **FIFO.** `enqueue` appends in the order given — callers pass display
///   order — and `startNext` pops the head.
/// - **Dedupe on entry.** An id already waiting or currently running is
///   skipped (its in-flight pass *is* the analysis); an id with a
///   recorded outcome re-queues — that is the re-analyze path — and its
///   old outcome is dropped so `status(of:)` never reports a stale result
///   for a game back in line.
/// - **A fresh batch resets the log.** `enqueue` onto a fully-idle queue
///   clears the finished log first, so "3 of 7" counts the batch the user
///   just started, not history. Enqueueing *during* a run extends the
///   same batch — the totals grow, which is correct: more work was added.
/// - **Outcomes are recorded, never inferred.** `finishCurrent` appends to
///   the log in completion order; `failures` filters it for the popover.
/// - **The queue owns the line; the controller owns the engine.**
///   `removeWaiting` and `clearWaiting` never touch `current` — stopping
///   the running pass is the controller's job (`skipCurrent`/`stopAll`),
///   which reports back through `finishCurrent(.cancelled)`.
internal struct AnalysisQueue<ID: Hashable & Sendable>: Sendable {
    
    // MARK: Outcomes
    
    /// How one game's pass ended.
    internal enum Outcome: Equatable, Sendable {
        case done
        case failed(message: String)
        /// Stopped by the user (skip / Stop All) or by teardown. Any
        /// evaluations recorded before the stop stay in the PGN — same
        /// contract as the driver's `stop()` always had.
        case cancelled
    }
    
    /// One completed item, in completion order.
    internal struct Finished: Equatable, Sendable {
        internal let id: ID
        internal let outcome: Outcome
        
        internal init(id: ID, outcome: Outcome) {
            self.id = id
            self.outcome = outcome
        }
    }
    
    /// The queue's answer to "where does this game stand?" — what the
    /// inspector's analysis control row switches on.
    internal enum ItemStatus: Equatable, Sendable {
        case notQueued
        /// In line; `position` is 1-based ("#2 in line").
        case waiting(position: Int)
        case running
        case finished(Outcome)
    }
    
    // MARK: State
    
    internal private(set) var waiting: [ID] = []
    internal private(set) var current: ID?
    internal private(set) var finished: [Finished] = []
    
    // MARK: Initializers
    
    internal init() {}
    
    // MARK: Derived
    
    /// Work exists: something is running or in line.
    internal var isActive: Bool { current != nil || !waiting.isEmpty }
    
    internal var remainingCount: Int {
        waiting.count + (current == nil ? 0 : 1)
    }
    
    internal var completedCount: Int { finished.count }
    
    /// The batch size as the user sees it: everything finished, running,
    /// or in line since the batch began.
    internal var totalCount: Int { completedCount + remainingCount }
    
    /// Failed items, in completion order, for the popover's error list.
    internal var failures: [Finished] {
        finished.filter {
            if case .failed = $0.outcome { return true }
            return false
        }
    }
    
    internal var hasFailures: Bool { !failures.isEmpty }
    
    // MARK: Mutations
    
    /// Appends `ids` in order, skipping any already waiting or running.
    /// Returns how many were actually added. See the type doc for the
    /// fresh-batch reset and the re-queue rule.
    @discardableResult
    internal mutating func enqueue(_ ids: [ID]) -> Int {
        if !isActive && !ids.isEmpty {
            // Fresh batch: without this, yesterday's log makes today's
            // progress read "5 of 7" before anything has run. Guarded on
            // non-empty input so an accidental `enqueue([])` doesn't
            // erase a drained batch's history for nothing.
            finished.removeAll()
        }
        var accepted = 0
        for id in ids {
            guard id != current, !waiting.contains(id) else { continue }
            finished.removeAll { $0.id == id }
            waiting.append(id)
            accepted += 1
        }
        return accepted
    }
    
    /// Promotes the head of the line to `current` and returns it; `nil`
    /// while something is already running or the line is empty. (The
    /// controller's loop shape: `while let id = queue.startNext()`.)
    internal mutating func startNext() -> ID? {
        guard current == nil, let next = waiting.first else { return nil }
        waiting.removeFirst()
        current = next
        return next
    }
    
    /// Records the running item's outcome and clears `current`. No-op
    /// with nothing running — teardown paths call this defensively.
    internal mutating func finishCurrent(_ outcome: Outcome) {
        guard let current else { return }
        finished.append(Finished(id: current, outcome: outcome))
        self.current = nil
    }
    
    /// Removes an id from the waiting line only — the running item is the
    /// controller's to stop (see the type doc's last bullet).
    internal mutating func removeWaiting(_ id: ID) {
        waiting.removeAll { $0 == id }
    }
    
    /// Empties the waiting line; `current` is untouched for the same
    /// reason as `removeWaiting`.
    internal mutating func clearWaiting() {
        waiting.removeAll()
    }
    
    /// Drops the finished log — the drained popover's Dismiss.
    internal mutating func clearFinished() {
        finished.removeAll()
    }
    
    // MARK: Queries
    
    /// The most recent word on `id`. A re-queued game reports its place in
    /// line, never its dropped prior outcome (see `enqueue`).
    internal func status(of id: ID) -> ItemStatus {
        if current == id { return .running }
        if let index = waiting.firstIndex(of: id) {
            return .waiting(position: index + 1)
        }
        if let record = finished.last(where: { $0.id == id }) {
            return .finished(record.outcome)
        }
        return .notQueued
    }
}
