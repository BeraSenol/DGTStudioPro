//
//  DGTSessionRecorderTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Coverage for `DGTSessionRecorder` — the mutable accumulator the connection
/// drives, turning a stream of physical-board snapshots into a finished
/// `DGTSessionRecording`. The pure replay analysis it produces is tested in
/// `DGTSessionRecordingTests`; this suite covers the accumulation itself.
///
/// `@MainActor`: `DGTSessionRecorder` is a `@MainActor final class` (it is
/// called from the `@MainActor` connection), so the suite must be main-actor
/// isolated to touch it at all — a genuine isolation requirement, unlike the
/// pure-value suites.
///
/// Offsets come from a real `ContinuousClock`, so the assertions check
/// *structure* — count, board values, identity carry-through, and that offsets
/// are non-negative and non-decreasing — never exact millisecond values, which
/// would be flaky.
@MainActor
@Suite("DGT Session Recorder")
struct DGTSessionRecorderTests {
    
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
    /// inspected it is at or before "now" — a light sanity check that the
    /// timestamp is wired through to the finished recording.
    @Test func recordedAtIsStampedAtConstruction() {
        let recorder = DGTSessionRecorder()
        let recording = recorder.finish()
        #expect(recording.recordedAt <= Date())
    }
}
