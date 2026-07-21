//
//  AnalysisQueueTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 19/07/2026.
//

import Testing
@testable import DGTStudioPro

/// Coverage for `AnalysisQueue` — the pure half of batch analysis,
/// extracted from `AnalysisQueueController` precisely so these decisions
/// can be pinned without SwiftData or a Stockfish subprocess (the M9
/// resolution of the `GameAnalysisDriver` audit line). The contracts
/// worth guarding:
///
///   1. FIFO with dedupe — an id already waiting or running never
///      double-enters; a finished id re-queues and drops its stale
///      outcome.
///   2. A fresh batch resets the finished log, so progress counts the
///      batch the user just started; enqueueing mid-run extends the same
///      batch instead.
///   3. The queue owns the line, the controller owns the engine —
///      `removeWaiting`/`clearWaiting` never touch `current`.
///
/// Runs on `String` ids: the type is generic exactly so this suite stays
/// hermetic. Not `@MainActor` — a pure `Sendable` value, matching every
/// other pure-value suite in the module.
@Suite("Analysis Queue")
struct AnalysisQueueTests {
    
    // MARK: FIFO & Advancement
    
    /// Display order in, display order out.
    @Test func enqueuePreservesOrderAndStartNextPopsTheHead() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b", "c"])
        
        #expect(queue.startNext() == "a")
        #expect(queue.current == "a")
        #expect(queue.waiting == ["b", "c"])
    }
    
    /// One running item at a time: `startNext` refuses while something is
    /// current, and again once the line is empty.
    @Test func startNextIsNilWhileRunningOrEmpty() {
        var queue = AnalysisQueue<String>()
        #expect(queue.startNext() == nil)
        
        queue.enqueue(["a", "b"])
        #expect(queue.startNext() == "a")
        #expect(queue.startNext() == nil)
        
        queue.finishCurrent(.done)
        #expect(queue.startNext() == "b")
        queue.finishCurrent(.done)
        #expect(queue.startNext() == nil)
    }
    
    /// The controller's loop shape end to end: three in, three recorded,
    /// in completion order.
    @Test func fullRunRecordsOutcomesInCompletionOrder() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b", "c"])
        
        while let id = queue.startNext() {
            queue.finishCurrent(id == "b" ? .failed(message: "boom") : .done)
        }
        
        #expect(queue.finished.map(\.id) == ["a", "b", "c"])
        #expect(queue.failures.map(\.id) == ["b"])
        #expect(queue.hasFailures)
        #expect(!queue.isActive)
    }
    
    // MARK: Dedupe
    
    /// An id already in line or on the engine never double-enters; new
    /// ids in the same call still land.
    @Test func enqueueSkipsWaitingAndRunningDuplicates() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b"])
        _ = queue.startNext()   // "a" running, "b" waiting
        
        let accepted = queue.enqueue(["a", "b", "c"])
        
        #expect(accepted == 1)
        #expect(queue.waiting == ["b", "c"])
        #expect(queue.current == "a")
    }
    
    /// Re-queueing a finished game is the re-analyze path: it rejoins the
    /// line and its stale outcome is dropped, so `status(of:)` reports
    /// the place in line, never yesterday's result.
    @Test func reenqueueingAFinishedGameDropsItsStaleOutcome() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b"])
        _ = queue.startNext()
        queue.finishCurrent(.failed(message: "boom"))   // "a" failed
        _ = queue.startNext()                            // "b" running
        
        let accepted = queue.enqueue(["a"])
        
        #expect(accepted == 1)
        #expect(queue.status(of: "a") == .waiting(position: 1))
        #expect(queue.failures.isEmpty)
        // Still the same (extended) batch: b running + a waiting + none finished.
        #expect(queue.totalCount == 2)
    }
    
    // MARK: Fresh Batch vs Extended Batch
    
    /// Enqueueing onto a fully-idle queue starts a fresh batch — the old
    /// log would otherwise make new progress read "2 of 3" at the start.
    @Test func enqueueFromIdleResetsTheFinishedLog() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b"])
        while queue.startNext() != nil { queue.finishCurrent(.done) }
        #expect(queue.completedCount == 2)
        
        queue.enqueue(["c"])
        
        #expect(queue.completedCount == 0)
        #expect(queue.totalCount == 1)
        #expect(queue.status(of: "a") == .notQueued)
    }
    
    /// `enqueue([])` on a drained queue is a no-op — it must not erase
    /// the history a popover may still be showing.
    @Test func emptyEnqueueOnIdleKeepsTheLog() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a"])
        _ = queue.startNext()
        queue.finishCurrent(.done)
        
        let accepted = queue.enqueue([])
        
        #expect(accepted == 0)
        #expect(queue.completedCount == 1)
    }
    
    /// Enqueueing during a run extends the batch: totals grow, the log
    /// stays — more work was added to the same run.
    @Test func enqueueDuringARunExtendsTheBatch() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b"])
        _ = queue.startNext()
        queue.finishCurrent(.done)
        _ = queue.startNext()   // "b" running, one finished
        
        queue.enqueue(["c"])
        
        #expect(queue.completedCount == 1)
        #expect(queue.totalCount == 3)
    }
    
    // MARK: Line vs Engine Ownership
    
    /// `removeWaiting` only touches the line: the running item stays put
    /// (stopping it is the controller's job), the named waiter leaves.
    @Test func removeWaitingNeverTouchesTheRunningItem() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b", "c"])
        _ = queue.startNext()
        
        queue.removeWaiting("a")    // running — untouched
        queue.removeWaiting("c")    // waiting — gone
        
        #expect(queue.current == "a")
        #expect(queue.waiting == ["b"])
    }
    
    /// `clearWaiting` empties the line and nothing else — the running
    /// pass keeps going until the controller stops it.
    @Test func clearWaitingKeepsCurrentAndTheLog() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b", "c"])
        _ = queue.startNext()
        queue.finishCurrent(.done)
        _ = queue.startNext()   // "b" running
        
        queue.clearWaiting()
        
        #expect(queue.current == "b")
        #expect(queue.waiting.isEmpty)
        #expect(queue.completedCount == 1)
        #expect(queue.isActive)
    }
    
    /// Finishing with nothing running is a defensive no-op — teardown
    /// races call it after the loop already drained.
    @Test func finishCurrentWithoutCurrentIsANoOp() {
        var queue = AnalysisQueue<String>()
        queue.finishCurrent(.cancelled)
        #expect(queue.finished.isEmpty)
    }
    
    // MARK: Status & Counts
    
    /// One-based positions, and every shape of `status(of:)` at once.
    @Test func statusReportsEveryShape() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b", "c", "d"])
        _ = queue.startNext()
        queue.finishCurrent(.done)      // a finished
        _ = queue.startNext()           // b running; c, d waiting
        
        #expect(queue.status(of: "a") == .finished(.done))
        #expect(queue.status(of: "b") == .running)
        #expect(queue.status(of: "c") == .waiting(position: 1))
        #expect(queue.status(of: "d") == .waiting(position: 2))
        #expect(queue.status(of: "e") == .notQueued)
    }
    
    /// The counts the toolbar item renders: completed / total, with
    /// remaining covering both the runner and the line.
    @Test func countsTrackTheBatch() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b", "c"])
        _ = queue.startNext()
        queue.finishCurrent(.done)
        _ = queue.startNext()   // one finished, one running, one waiting
        
        #expect(queue.completedCount == 1)
        #expect(queue.remainingCount == 2)
        #expect(queue.totalCount == 3)
    }
    
    /// The popover's Dismiss: the log clears, the queue reads idle and
    /// failure-free.
    @Test func clearFinishedEmptiesTheLog() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a"])
        _ = queue.startNext()
        queue.finishCurrent(.failed(message: "boom"))
        #expect(queue.hasFailures)
        
        queue.clearFinished()
        
        #expect(queue.finished.isEmpty)
        #expect(!queue.hasFailures)
        #expect(!queue.isActive)
    }
    
    /// A cancelled game counts as completed for batch progress (the run
    /// moved past it) and is not a failure.
    @Test func cancelledOutcomeCountsAsCompletedNotFailed() {
        var queue = AnalysisQueue<String>()
        queue.enqueue(["a", "b"])
        _ = queue.startNext()
        queue.finishCurrent(.cancelled)
        
        #expect(queue.status(of: "a") == .finished(.cancelled))
        #expect(queue.completedCount == 1)
        #expect(!queue.hasFailures)
    }
}
