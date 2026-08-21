import Foundation
import Testing

@testable import DGTStudioPro

/// The graph's spatial mapping. Nonisolated: pure value types, no
/// fixtures, the `EvaluationBarReadingTests` shape.
///
/// The suite exists because this arithmetic now has **two** consumers pointing
/// in opposite directions, and the round trip between them is the property
/// neither one can check alone.
@Suite("Evaluation Graph Geometry")
struct EvaluationGraphGeometryTests {

    // MARK: Degenerate Inputs

    /// Fewer than two plies has no step, which is the same threshold
    /// `EvaluationGraphView` guards its drawing on. Pinned so the two cannot
    /// drift apart - a geometry that answered for one ply would place it at
    /// x = 0 and draw a curve with no width.
    @Test(arguments: [0, 1])
    func aCurveShorterThanTwoPliesHasNoStep(plyCount: Int) {
        let geometry = EvaluationGraphGeometry(width: 400, plyCount: plyCount)
        #expect(geometry.step == nil)
        #expect(geometry.x(forPly: 0) == nil)
        #expect(geometry.ply(nearestTo: 200) == nil)
    }

    /// A zero-width rect is the first layout pass, before SwiftUI has proposed
    /// a size. Dividing by it yields infinity rather than trapping, so nothing
    /// would have complained - the points would simply all be placed at
    /// infinity for one frame.
    @Test func zeroWidthHasNoStep() {
        #expect(EvaluationGraphGeometry(width: 0, plyCount: 40).step == nil)
    }

    // MARK: Placement

    /// The ends are the assertion that matters: the first ply sits on the
    /// leading edge and the last on the trailing one, which is what makes the
    /// curve span its rect exactly rather than stopping one step short.
    @Test func theCurveSpansItsFullWidth() throws {
        let geometry = EvaluationGraphGeometry(width: 300, plyCount: 4)
        let first = try #require(geometry.x(forPly: 0))
        let middle = try #require(geometry.x(forPly: 1))
        let last = try #require(geometry.x(forPly: 3))

        #expect(first == 0)
        #expect(middle == 100)
        #expect(last == 300)
    }

    /// Offsets, not absolute coordinates - the caller adds its own `minX`.
    /// Stated in the doc and pinned here, because the difference is invisible
    /// in the one caller whose rect happens to start at zero, which is both of
    /// them today.
    @Test func placementIsRelativeToTheLeadingEdge() {
        let geometry = EvaluationGraphGeometry(width: 100, plyCount: 2)
        #expect(geometry.x(forPly: 0) == 0)
    }

    @Test(arguments: [-1, 4, 99])
    func aPlyOutsideTheCurveHasNoPlace(ply: Int) {
        #expect(EvaluationGraphGeometry(width: 300, plyCount: 4).x(forPly: ply) == nil)
    }

    // MARK: Hit-testing

    /// The round trip, which is the whole reason the type exists: a ply's own
    /// position must map back to that ply. Checked across the full curve rather
    /// than at a sample, because an off-by-one in the rounding would survive
    /// any single probe taken at an endpoint.
    @Test func everyPlysPositionMapsBackToIt() throws {
        let geometry = EvaluationGraphGeometry(width: 517, plyCount: 63)
        for ply in 0..<63 {
            let x = try #require(geometry.x(forPly: ply))
            #expect(geometry.ply(nearestTo: x) == ply, "ply \(ply) at x=\(x)")
        }
    }

    /// Nearest, not floor: a pointer just past the midpoint belongs to the next
    /// ply. Floor would bias every read-out one ply early, which reads as the
    /// graph being subtly out of step with the move list beside it.
    @Test func aPointerPastTheMidpointBelongsToTheNextPly() {
        let geometry = EvaluationGraphGeometry(width: 300, plyCount: 4)
        #expect(geometry.ply(nearestTo: 49) == 0)
        #expect(geometry.ply(nearestTo: 51) == 1)
    }

    /// Clamped rather than nil outside the curve - a pointer one pixel past the
    /// last point is still asking about the last ply, and a read-out that
    /// blanks at the very edge of the graph reads as a defect in the read-out.
    @Test func pointersOutsideTheCurveClampToItsEnds() {
        let geometry = EvaluationGraphGeometry(width: 300, plyCount: 4)
        #expect(geometry.ply(nearestTo: -80) == 0)
        #expect(geometry.ply(nearestTo: 9_000) == 3)
    }
}

/// What the magnifier window says about one ply.
@Suite("Evaluation Graph Reading")
struct EvaluationGraphReadingTests {

    private let moves = ["e4", "e5", "Nf3", "Nc6", "Bb5"]

    // MARK: Move Grammar

    /// White plies take the number, black plies take the ellipsis - the
    /// display convention, deliberately not `PGNSerializer`'s file form, which
    /// never has to name a black ply on its own.
    @Test func whitePliesNumberAndBlackPliesElide() throws {
        let white = try #require(EvaluationGraphReading(ply: 0, moves: moves, evaluations: []))
        let black = try #require(EvaluationGraphReading(ply: 1, moves: moves, evaluations: []))
        let later = try #require(EvaluationGraphReading(ply: 4, moves: moves, evaluations: []))

        #expect(white.move == "1. e4")
        #expect(black.move == "1… e5")
        #expect(later.move == "3. Bb5")
    }

    @Test(arguments: [-1, 5, 40])
    func aPlyOutsideTheGameHasNoReading(ply: Int) {
        #expect(EvaluationGraphReading(ply: ply, moves: moves, evaluations: []) == nil)
    }

    // MARK: Evaluation Grammar

    /// The label is `EvaluationBarReading`'s verbatim, so the window and the
    /// bar cannot describe one number two ways. Asserted *against that type*
    /// rather than against a literal: a literal here would pass while the two
    /// grammars diverged, which is precisely the disagreement being prevented.
    @Test func theEvaluationLabelIsTheBarsOwn() throws {
        let evaluations: [Evaluation?] = [.centipawns(34), .centipawns(-150), .mate(3), nil, nil]

        for ply in 0..<5 {
            let reading = try #require(
                EvaluationGraphReading(ply: ply, moves: moves, evaluations: evaluations)
            )
            #expect(reading.evaluation == EvaluationBarReading(evaluations[ply]).label)
        }
    }

    /// An unevaluated ply still happened, so it still reads - it just folds to
    /// the bar's nil rule. The alternative, failing the whole reading, would
    /// blank the move name too and make a partially analyzed game unreadable
    /// exactly where the analysis stopped.
    @Test func anUnevaluatedPlyStillNamesItsMove() throws {
        let reading = try #require(
            EvaluationGraphReading(ply: 2, moves: moves, evaluations: [])
        )
        #expect(reading.move == "2. Nf3")
        #expect(reading.evaluation == EvaluationBarReading(nil).label)
    }

    /// `PGN.evaluations` is empty or exactly as long as `moves` by documented
    /// invariant, but the reading must not trap if that invariant is ever
    /// violated - a short array is a data defect, and a crash in a read-out is
    /// a worse way to learn about it than a dash.
    @Test func aShortEvaluationArrayDoesNotTrap() throws {
        let reading = try #require(
            EvaluationGraphReading(ply: 4, moves: moves, evaluations: [.centipawns(10)])
        )
        #expect(reading.move == "3. Bb5")
        #expect(reading.evaluation == EvaluationBarReading(nil).label)
    }
}
