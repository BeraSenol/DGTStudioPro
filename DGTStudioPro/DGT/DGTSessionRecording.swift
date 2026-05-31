//
//  DGTSessionRecording.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 31/05/2026.
//

import Foundation

// MARK: Recording

/// An immutable, `Codable` recording of a live board session: the ordered
/// stream of physical-board snapshots, each stamped with a millisecond offset
/// from the session's start, plus the board's identity.
///
/// Capture one from real hardware via `DGTConnection`'s recorder, then replay
/// it through the pure analysis below to develop and regression-test move
/// reconstruction / recovery against genuine board behavior — no board required
/// after the first capture. This complements `DGTBoardSimulator` (which
/// *fabricates* lift/place sequences); this replays *recorded* ones.
///
/// Snapshots are captured on every physical change (each field update), so a
/// recording preserves the intermediate states of a slide and any sensor
/// flicker — exactly the noise reconstruction must tolerate. Which snapshots the
/// live session would actually have evaluated (the 300 ms debounce) is
/// recomputed at replay from the timestamps via `settledBoards(quiescence:)`, so
/// the quiescence window can be re-tuned offline without re-capturing.
///
/// Pure value type: no logging, no I/O beyond the explicit `Codable`/export
/// helpers. It reads the (also pure) chess and reconstruction types; it never
/// touches `DGTLiveSession` or the serial layer.
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

    /// The board snapshots the live session would have *settled* on: each entry
    /// followed by a quiescence-length gap with no further change, plus the
    /// final snapshot. Reproduces the live 300 ms debounce from the recorded
    /// timestamps — deterministically, with no waiting — so intermediate
    /// mid-move states are filtered out exactly as the real timer filters them.
    internal func settledBoards(quiescence: Duration = .milliseconds(300)) -> [Position] {
        guard !entries.isEmpty else { return [] }
        let gap = quiescence.inMilliseconds
        var settled: [Position] = []
        for index in entries.indices {
            let isLast = index == entries.index(before: entries.endIndex)
            let stillLongEnough = isLast
                || (entries[index + 1].offsetMillis - entries[index].offsetMillis) >= gap
            if stillLongEnough {
                settled.append(entries[index].board)
            }
        }
        return settled
    }

    /// One settled snapshot and what the reconstructor concluded for it.
    internal struct Step: Equatable {
        internal let board: Position
        internal let outcome: DGTReconstruction
    }

    /// Walks the settled snapshots through the pure reconstructor starting from
    /// `initialState`, advancing the game on each committed `.move`, and returns
    /// the per-snapshot outcome.
    ///
    /// This is the replay that answers the hardware session's central question —
    /// *does reconstruction hold up against this real game, or does sensor noise
    /// trip a spurious `.unresolved` (false desync)?* The state advances only on
    /// `.move`, mirroring the live session: `.castlingInProgress` and
    /// `.correctable` don't advance (the completing `.move` lands on a later
    /// settled snapshot), and a genuine fumble shows up as `.unresolved`.
    ///
    /// Pure — no `DGTLiveSession`, no timer, no I/O. Also reusable behind a
    /// future in-app "replay this log" debug view.
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

/// Builds a `DGTSessionRecording` from live board changes. Owned (optionally) by
/// `DGTConnection`, which calls `record(_:)` on each physical change. MainActor
/// only — it's driven from the connection, which is `@MainActor`.
@MainActor
internal final class DGTSessionRecorder {

    private let clock = ContinuousClock()
    private let start: ContinuousClock.Instant
    private let recordedAt = Date.now
    private(set) internal var entries: [DGTSessionRecording.Entry] = []

    /// Stamped onto the finished recording; set from the board's reported
    /// identity when recording stops (identity arrives during the handshake,
    /// possibly after recording began).
    internal var identity = DGTSessionRecording.Identity()

    internal init() {
        start = clock.now
    }

    internal func record(_ board: Position) {
        entries.append(.init(offsetMillis: (clock.now - start).inMilliseconds, board: board))
    }

    internal func finish() -> DGTSessionRecording {
        DGTSessionRecording(identity: identity, recordedAt: recordedAt, entries: entries)
    }
}

// MARK: Duration → milliseconds

extension Duration {
    /// Whole milliseconds in this duration (truncating). `Duration.components`
    /// gives `(seconds, attoseconds)`; 1 ms = 1e15 attoseconds.
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

    /// Presents an `NSSavePanel` and writes the recording as JSON. Returns the
    /// URL written, or nil if the user cancelled. Throws on encode/write
    /// failure. Mirrors `DGTSessionLog.exportViaSavePanel()`.
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
