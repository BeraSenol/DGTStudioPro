import Foundation

// MARK: Recording

/// Immutable `Codable` recording of a live board session: timestamped physical-board snapshots plus
/// the board identity. Captured from hardware, replayed deterministically for regression - pure;
/// reads the chess/reconstruction types, never the session.
///
/// **The one place the app persists a `Position`.** `Entry.board` is what makes `Position: Codable`
/// load-bearing rather than incidental, so its JSON shape - `{"squares":[{"rawValue":N} × 64]}` -
/// is a file format. Nothing else encodes one; drafts store a FEN string instead.
struct DGTSessionRecording: Codable, Equatable {
    
    /// One captured physical-board snapshot.
    struct Entry: Codable, Equatable {
        /// Milliseconds since the first recorded snapshot.
        let offsetMillis: Int
        let board: Position
    }
    
    /// The board's reported identity, for fixture provenance.
    struct Identity: Codable, Equatable {
        var serialNumber: String?
        var version: String?
        var trademark: String?
        
        init(
            serialNumber: String? = nil,
            version: String? = nil,
            trademark: String? = nil
        ) {
            self.serialNumber = serialNumber
            self.version = version
            self.trademark = trademark
        }
    }
    
    var identity: Identity
    var recordedAt: Date
    var entries: [Entry]
    
    init(
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
    
    /// The snapshots the live session would have *settled* on - reproduces the 300 ms debounce from
    /// recorded timestamps, deterministically: an entry settles when nothing follows it inside the
    /// window. **Test-only**, like everything else in this extension.
    func settledBoards(quiescence: Duration = .milliseconds(300)) -> [Position] {
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
    struct Step: Equatable {
        let board: Position
        let outcome: DGTReconstruction
    }
    
    /// Walks the settled snapshots through the pure reconstructor from `initialState`, advancing
    /// only on committed `.move` - the field-desync replay ("would this recording trip a false
    /// desync?").
    func reconstructions(
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
    
    /// Pretty-printed and key-sorted deliberately: a recording is read and diffed by hand when it
    /// becomes a regression fixture. That formatting is most of the file size noted at `maxEntries`.
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// **Test-only** - the app writes recordings and never reads one back.
    static func decoded(from data: Data) throws -> DGTSessionRecording {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DGTSessionRecording.self, from: data)
    }
}

extension Duration {
    /// Whole milliseconds (truncating); 1 ms = 1e15 attoseconds. Internal since the M18
    /// recorder split - both halves timestamp through it (`fileprivate` held while they
    /// shared a file, and the split is not a reason to mint a second conversion).
    var inMilliseconds: Int {
        let parts = components
        return Int(parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000)
    }
}

// MARK: Save-Panel Export (macOS)

// Always true - this app has one platform.
#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

extension DGTSessionRecording {
    
    /// Save panel + JSON write. Deliberately throws (unlike the log's panel): the caller shows the
    /// failure.
    @MainActor
    @discardableResult
    func exportViaSavePanel() throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "DGTSession-\(Self.fileTimestamp()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try jsonData().write(to: url)
        return url
    }
    
    /// A formatter per call, deliberately: `DateFormatter` is not `Sendable`, so a cached
    /// `static let` out here - outside any isolated type - would not compile. `DGTSessionLog`
    /// caches its two because they sit inside a `@MainActor` class.
    private static func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: .now)
    }
}
#endif
