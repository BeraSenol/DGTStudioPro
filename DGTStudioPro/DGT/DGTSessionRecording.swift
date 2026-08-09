import Foundation

// MARK: Recording

/// Immutable `Codable` recording of a live board session: timestamped physical-board snapshots
/// plus the board identity. Captured from hardware, replayed deterministically for regression —
/// pure; reads the chess/reconstruction types, never the session.
internal struct DGTSessionRecording: Codable, Equatable {
    
    /// One captured physical-board snapshot.
    internal struct Entry: Codable, Equatable {
        /// Milliseconds since the first recorded snapshot.
        internal let offsetMillis: Int
        internal let board: Position
    }
    
    /// The board's reported identity, for fixture provenance.
    internal struct Identity: Codable, Equatable {
        internal var serialNumber: String?
        internal var version: String?
        internal var trademark: String?
        
        internal init(
            serialNumber: String? = nil,
            version: String? = nil,
            trademark: String? = nil
        ) {
            self.serialNumber = serialNumber
            self.version = version
            self.trademark = trademark
        }
    }
    
    internal var identity: Identity
    internal var recordedAt: Date
    internal var entries: [Entry]
    
    internal init(
        identity: Identity = .init(),
        recordedAt: Date = .now,
        entries: [Entry] = []
    ) {
        self.identity = identity
        self.recordedAt = recordedAt
        self.entries = entries
    }
}

// MARK: Replay Analysis (pure)

extension DGTSessionRecording {
    
    /// The snapshots the live session would have *settled* on — reproduces the 300 ms debounce from
    /// recorded timestamps, deterministically.
    internal func settledBoards(quiescence: Duration = .milliseconds(300)) -> [Position] {
        let gap = quiescence.inMilliseconds
        var settled: [Position] = []
        for (index, entry) in entries.enumerated() {
            let next = index + 1
            let isSettled = next == entries.count
            || entries[next].offsetMillis - entry.offsetMillis >= gap
            if isSettled { settled.append(entry.board) }
        }
        return settled
    }
    
    /// One settled snapshot and what the reconstructor concluded for it.
    internal struct Step: Equatable {
        internal let board: Position
        internal let outcome: DGTReconstruction
    }
    
    /// Walks the settled snapshots through the pure reconstructor from `initialState`, advancing
    /// only on committed `.move` — the field-desync replay ("would this recording trip a false
    /// desync?").
    internal func reconstructions(
        from initialState: GameState,
        quiescence: Duration = .milliseconds(300)
    ) -> [Step] {
        var state = initialState
        var steps: [Step] = []
        for board in settledBoards(quiescence: quiescence) {
            let outcome = DGTReconstructor.reconstruct(from: state, physical: board)
            steps.append(Step(board: board, outcome: outcome))
            if case .move(let move) = outcome {
                state = state.applying(move)
            }
        }
        return steps
    }
}

// MARK: Codable Convenience

extension DGTSessionRecording {
    
    internal func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    internal static func decoded(from data: Data) throws -> DGTSessionRecording {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DGTSessionRecording.self, from: data)
    }
}

// MARK: Recorder (mutable accumulator)

/// Accumulates a recording from live changes; MainActor — driven from the connection.
@MainActor
internal final class DGTSessionRecorder {
    
    private let clock = ContinuousClock()
    private let start: ContinuousClock.Instant
    private let recordedAt = Date.now
    private(set) internal var entries: [DGTSessionRecording.Entry] = []
    
    /// Stamped when recording stops — identity arrives during the handshake, possibly late.
    internal var identity = DGTSessionRecording.Identity()
    
    internal init() {
        start = clock.now
    }
    
    /// Hard cap — the recorder's half of the growth bound (the log's is `maxEntries`). A forgotten
    /// marathon recording stays under a megabyte; replay reads gaps between retained neighbours.
    private let maxEntries = 10_000
    
    internal func record(_ board: Position) {
        entries.append(.init(offsetMillis: (clock.now - start).inMilliseconds, board: board))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
    
    internal func finish() -> DGTSessionRecording {
        DGTSessionRecording(identity: identity, recordedAt: recordedAt, entries: entries)
    }
}

// MARK: Duration → milliseconds

extension Duration {
    /// Whole milliseconds (truncating); 1 ms = 1e15 attoseconds.
    fileprivate var inMilliseconds: Int {
        let parts = components
        return Int(parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000)
    }
}

// MARK: Save-Panel Export (macOS)

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

extension DGTSessionRecording {
    
    /// Save panel + JSON write. Deliberately throws (unlike the log's panel): the caller shows the
    /// failure.
    @MainActor
    @discardableResult
    internal func exportViaSavePanel() throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "DGTSession-\(Self.fileTimestamp()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try jsonData().write(to: url)
        return url
    }
    
    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: .now)
    }
}
#endif
