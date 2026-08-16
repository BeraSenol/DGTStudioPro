/// Pure decisions behind batch analysis - ordering, dedupe, advancement, outcomes - extracted
/// so the interesting choices are suited without an engine. FIFO; enqueue dedupes against line
/// and running; a fresh batch clears the finished log; the running item is the controller's to stop.
struct AnalysisQueue<ID: Hashable & Sendable>: Sendable {
    
    // MARK: Outcomes
    
    /// How one game's pass ended.
    enum Outcome: Equatable, Sendable {
        case done
        case failed(message: String)
        /// Stopped by user or teardown; evaluations recorded before the stop stay.
        case cancelled
        
        /// The failure filter, named once instead of an `if case` per site.
        var isFailure: Bool {
            if case .failed = self { true } else { false }
        }
    }
    
    /// One completed item, in completion order.
    struct Finished: Equatable, Sendable {
        let id: ID
        let outcome: Outcome
    }
    
    /// The queue's answer to "where does this game stand?".
    enum ItemStatus: Equatable, Sendable {
        case notQueued
        /// In line; `position` is 1-based.
        case waiting(position: Int)
        case running
        case finished(Outcome)
    }
    
    // MARK: State
    
    private(set) var waiting: [ID] = []
    private(set) var current: ID?
    private(set) var finished: [Finished] = []
    
    // MARK: Initializers
    
    init() {}
    
    // MARK: Derived
    
    /// Work exists: something is running or in line.
    var isActive: Bool { current != nil || !waiting.isEmpty }
    
    var remainingCount: Int {
        waiting.count + (current == nil ? 0 : 1)
    }
    
    var completedCount: Int { finished.count }
    
    /// The batch size as the user sees it.
    var totalCount: Int { completedCount + remainingCount }

    /// The 1-based position the batch is on - one spelling, because there were two: the window and
    /// the toolbar once disagreed by one.
    var batchPosition: Int {
        isActive ? min(completedCount + 1, totalCount) : completedCount
    }
    
    /// Failed items, completion order.
    var failures: [Finished] {
        finished.filter(\.outcome.isFailure)
    }
    
    /// `contains`, not `!failures.isEmpty` - the array form built the whole list to ask if it was empty.
    var hasFailures: Bool {
        finished.contains { $0.outcome.isFailure }
    }
    
    // MARK: Mutations
    
    /// Appends in order, skipping already-waiting/running; returns how many were added.
    @discardableResult
    mutating func enqueue(_ ids: [ID]) -> Int {
        if !isActive && !ids.isEmpty {
            // Fresh batch: without this, yesterday's log makes today read "5 of 7" before anything runs.
            // Guarded on non-empty input so `enqueue([])` doesn't erase a drained batch's history.
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
    
    /// Promotes the head to `current`; nil while running or empty. (Loop shape: `while let`.)
    mutating func startNext() -> ID? {
        guard current == nil, let next = waiting.first else { return nil }
        waiting.removeFirst()
        current = next
        return next
    }
    
    /// Records the outcome, clears `current`; no-op with nothing running (teardown calls defensively).
    mutating func finishCurrent(_ outcome: Outcome) {
        guard let current else { return }
        finished.append(Finished(id: current, outcome: outcome))
        self.current = nil
    }
    
    /// Waiting line only - the running item is the controller's to stop.
    mutating func removeWaiting(_ id: ID) {
        waiting.removeAll { $0 == id }
    }
    
    /// Empties the waiting line; `current` untouched, same reason.
    mutating func clearWaiting() {
        waiting.removeAll()
    }
    
    /// Drops the finished log - the drained popover's Dismiss.
    mutating func clearFinished() {
        finished.removeAll()
    }
    
    // MARK: Queries
    
    /// The most recent word on `id` - a re-queued game reports its place in line, never its dropped outcome.
    func status(of id: ID) -> ItemStatus {
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
