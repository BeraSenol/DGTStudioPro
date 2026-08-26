import Testing
import CoreGraphics
@testable import DGTStudioPro

/// Pins the Fritsch-Carlson tangents (M18 Phase 2 - `EvaluationGraphGeometry.monotoneSlopes`).
/// The no-overshoot claim rested on a 17 Aug visual comparison; here it is a checked property:
/// the curve the view draws through these tangents cannot leave the interval between two
/// plies, so every visible extreme is a real one. Nonisolated - pure arithmetic, load-bearing.
@Suite("Evaluation Graph Slopes")
struct EvaluationGraphSlopesTests {

    // MARK: Oracle

    /// The cubic Hermite the view's Bézier *is* (control points a third of the span along each
    /// tangent are exactly the Hermite→Bézier conversion), evaluated directly - an independent
    /// spelling of the same curve, which is what makes it an oracle rather than a copy.
    private static func hermite(
        t: CGFloat, p1: CGPoint, p2: CGPoint, m1: CGFloat, m2: CGFloat
    ) -> CGFloat {
        let dx = p2.x - p1.x
        let t2 = t * t
        let t3 = t2 * t
        return (2 * t3 - 3 * t2 + 1) * p1.y
            + (t3 - 2 * t2 + t) * dx * m1
            + (-2 * t3 + 3 * t2) * p2.y
            + (t3 - t2) * dx * m2
    }

    /// Asserts the whole curve stays inside each ply interval, 33 samples per segment.
    private static func assertNoOvershoot(_ points: [CGPoint]) {
        let slopes = EvaluationGraphGeometry.monotoneSlopes(through: points)
        for i in 0 ..< points.count - 1 {
            let low = min(points[i].y, points[i + 1].y) - 1e-9
            let high = max(points[i].y, points[i + 1].y) + 1e-9
            for sample in 0 ... 32 {
                let y = hermite(
                    t: CGFloat(sample) / 32,
                    p1: points[i], p2: points[i + 1],
                    m1: slopes[i], m2: slopes[i + 1]
                )
                #expect(y >= low && y <= high)
            }
        }
    }

    /// Evenly spaced plies, the view's arrangement.
    private static func points(_ ys: [CGFloat]) -> [CGPoint] {
        ys.enumerated().map { CGPoint(x: CGFloat($0.offset) * 10, y: $0.element) }
    }

    /// Deterministic by seed - a flaky property test is worse than none.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    // MARK: The Property

    /// Random win-probability sequences at several lengths, all seeds fixed: the curve never
    /// leaves any interval. This is the sentence the view's doc states, as a failure.
    @Test(arguments: [UInt64](2...9))
    func randomSequencesNeverOvershoot(seed: UInt64) {
        var generator = SeededGenerator(state: seed &* 0x9E3779B97F4A7C15)
        for length in [2, 3, 5, 8, 13, 24, 40] {
            let ys = (0 ..< length).map { _ in CGFloat(Double.random(in: 0...1, using: &generator)) }
            Self.assertNoOvershoot(Self.points(ys))
        }
    }

    /// The violent case that motivated the 17 Aug replacement - the back-and-forth preview
    /// data, where Catmull-Rom invented peaks higher than any evaluation in the game.
    @Test func theBackAndForthPreviewDataNeverOvershoots() {
        Self.assertNoOvershoot(Self.points([
            0.50, 0.55, 0.48, 0.58, 0.45, 0.52, 0.40, 0.55,
            0.42, 0.60, 0.38, 0.52, 0.45, 0.50, 0.55, 0.48,
            0.58, 0.42, 0.55, 0.50, 0.45, 0.52, 0.48, 0.50
        ]))
    }

    // MARK: The Two Clauses

    /// A direction reversal gets a flat tangent - the clause that removes invented peaks.
    @Test func aReversalGetsAFlatTangent() {
        let slopes = EvaluationGraphGeometry.monotoneSlopes(
            through: Self.points([0, 10, 0])
        )
        #expect(slopes[1] == 0)
    }

    /// On a monotone run the average is clamped to three times the gentler neighbour:
    /// secants 0.1 then 10 average to 5.05, and 0.3 is what survives.
    @Test func theGentlerNeighbourClampsTheAverage() {
        let slopes = EvaluationGraphGeometry.monotoneSlopes(
            through: Self.points([0, 1, 101])
        )
        #expect(abs(slopes[1] - 0.3) < 1e-9)
    }

    // MARK: Edges

    /// Endpoints take their one-sided secants verbatim.
    @Test func endpointsTakeTheirSecants() {
        let slopes = EvaluationGraphGeometry.monotoneSlopes(
            through: Self.points([0, 5, 5, 20])
        )
        #expect(slopes.first == 0.5)
        #expect(slopes.last == 1.5)
    }

    /// Under two points there is no step to describe; a duplicated x is a slope of zero,
    /// never a NaN in a `Path`.
    @Test func degenerateInputsStayFinite() {
        #expect(EvaluationGraphGeometry.monotoneSlopes(through: []) == [])
        #expect(EvaluationGraphGeometry.monotoneSlopes(through: [CGPoint(x: 0, y: 3)]) == [0])

        let duplicated = EvaluationGraphGeometry.monotoneSlopes(
            through: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 5)]
        )
        #expect(duplicated == [0, 0])
        #expect(duplicated.allSatisfy { $0.isFinite })
    }
}
