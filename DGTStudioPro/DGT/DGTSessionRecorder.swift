import Foundation

// MARK: Recorder (mutable accumulator)


/// Accumulates a recording from live changes; MainActor - driven from the connection.
@MainActor
final class DGTSessionRecorder {
    
    private let clock = ContinuousClock()
    private let start: ContinuousClock.Instant
    private let recordedAt = Date.now
    private(set) var entries: [DGTSessionRecording.Entry] = []
    
    /// Stamped when recording stops - identity arrives during the handshake, possibly late.
    var identity = DGTSessionRecording.Identity()
    
    init() {
        start = clock.now
    }
    
    /// Hard cap on retained snapshots - a **memory** bound, not a file-size one: each snapshot is
    /// 64 `{"rawValue":N}` objects, roughly 2.6 KB pretty-printed, so a full ring exports at tens
    /// of megabytes and one megabyte arrives around 400 entries. Offsets stay absolute after a
    /// drop, so replay still reads correct gaps between the retained neighbours.
    private let maxEntries = 10_000
    
    func record(_ board: Position) {
        entries.append(.init(offsetMillis: (clock.now - start).inMilliseconds, board: board))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
    
    func finish() -> DGTSessionRecording {
        DGTSessionRecording(identity: identity, recordedAt: recordedAt, entries: entries)
    }
}

// MARK: Duration → milliseconds
