import Testing
import Foundation
@testable import DGTStudioPro

/// The mutable accumulator the connection drives (@MainActor - a genuine isolation). Offsets
/// asserted non-negative and non-decreasing, never exact milliseconds.
@MainActor
@Suite("DGT Session Recorder")
struct DGTSessionRecorderTests {
    private let cap = 10_000

    // MARK: Growth Bound (M10.2)

    /// The recorder's ring, mirroring the log's: a forgotten recording must
    /// not grow without bound, and the *newest* window is the one worth
    /// keeping. Markers first, then a full cap of clean boards - the
    /// markers must be gone.
    @Test func ringBufferEvictsOldestPastCap() {
        let recorder = DGTSessionRecorder()
        var marker = Position.starting
        marker[Squares.e4] = .whiteQueen

        for _ in 0..<100 { recorder.record(marker) }
        for _ in 0..<cap { recorder.record(.starting) }

        #expect(recorder.entries.count == cap)
        #expect(recorder.entries.first?.board == .starting)   // markers evicted
        #expect(!recorder.entries.contains { $0.board == marker })
    }

    @Test func finishCapturesRecordedBoardsAndIdentity() {
        let recorder = DGTSessionRecorder()

        let first = Position.starting
        let second = Position.make { $0[Squares.e4] = .whitePawn }
        recorder.record(first)
        recorder.record(second)

        // Identity typically arrives during the handshake, after recording began.
        recorder.identity = .init(serialNumber: "SN-1", version: "2.5", trademark: "DGT")

        let recording = recorder.finish()

        #expect(recording.entries.count == 2)
        #expect(recording.entries[0].board == first)
        #expect(recording.entries[1].board == second)

        // Offsets are real-clock values: assert only the invariants, not exact ms.
        #expect(recording.entries.map(\.offsetMillis).allSatisfy { $0 >= 0 })
        #expect(recording.entries[0].offsetMillis <= recording.entries[1].offsetMillis)

        #expect(recording.identity.serialNumber == "SN-1")
        #expect(recording.identity.version == "2.5")
        #expect(recording.identity.trademark == "DGT")
    }

    @Test func freshRecorderFinishesEmptyWithDefaultIdentity() {
        let recorder = DGTSessionRecorder()
        let recording = recorder.finish()

        #expect(recording.entries.isEmpty)
        #expect(recording.identity.serialNumber == nil)
        #expect(recording.identity.version == nil)
        #expect(recording.identity.trademark == nil)
    }

    /// `recordedAt` is stamped at construction, so by the time `finish()` is
    /// inspected it is at or before "now" - a light sanity check that the
    /// timestamp is wired through to the finished recording.
    @Test func recordedAtIsStampedAtConstruction() {
        let recorder = DGTSessionRecorder()
        let recording = recorder.finish()
        #expect(recording.recordedAt <= Date())
    }
}
