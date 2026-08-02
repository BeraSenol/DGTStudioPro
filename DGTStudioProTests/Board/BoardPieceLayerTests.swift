//
//  BoardPieceLayerTests.swift
//  DGTStudioProTests
//
//  Created by Supreme Leader on 02/08/2026.
//

import Testing
@testable import DGTStudioPro

/// The glide-duration guardrails (2 Aug 2026, when the duration became a
/// preference). Nonisolated deliberately: the subject is the `static`
/// clamp, plain value arithmetic — no view is rendered here.
struct BoardPieceLayerTests {

    @Test func inRangeValuesPassThrough() {
        #expect(BoardPieceLayer.clampedDuration(0.22) == 0.22)
        #expect(BoardPieceLayer.clampedDuration(0.5) == 0.5)
    }

    @Test func endpointsAreThemselvesLegal() {
        #expect(BoardPieceLayer.clampedDuration(0.1) == 0.1)
        #expect(BoardPieceLayer.clampedDuration(1.0) == 1.0)
    }

    /// The repair direction: below folds up to the floor, above folds down
    /// to the ceiling — a hand-edited default is corrected, not obeyed.
    @Test func outOfRangeValuesFoldToTheNearestBound() {
        #expect(BoardPieceLayer.clampedDuration(0.0) == 0.1)
        #expect(BoardPieceLayer.clampedDuration(-3) == 0.1)
        #expect(BoardPieceLayer.clampedDuration(2.5) == 1.0)
        #expect(BoardPieceLayer.clampedDuration(.infinity) == 1.0)
    }

    /// The default must sit inside the range it is clamped to, or a fresh
    /// install would ship a value the first read rewrites.
    @Test func defaultLiesWithinTheRange() {
        #expect(BoardPieceLayer.durationRange.contains(BoardPieceLayer.defaultDuration))
    }
}
