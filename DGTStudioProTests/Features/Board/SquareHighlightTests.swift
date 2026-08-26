import Testing
@testable import DGTStudioPro

/// Pins the flag algebra (M18 Phase 1). Nonisolated: a `Sendable` `OptionSet` with one
/// producer and one consumer. The distinctness pin is the one that can fail for real - a
/// seventh flag pasted with an existing shift silently merges two meanings, and the views
/// would render the union without anyone deciding it.
@Suite("Square Highlight")
struct SquareHighlightTests {

    private static let all: [SquareHighlight] = [
        .lastMove, .check, .selected, .attention, .target, .hint
    ]

    /// Six flags, six distinct single bits - `UInt8` leaves room for exactly two more, which
    /// this pin turns from a comment into arithmetic.
    @Test func everyFlagIsADistinctSingleBit() {
        let raws = Self.all.map(\.rawValue)
        #expect(raws == [1, 2, 4, 8, 16, 32])
        #expect(Set(raws).count == 6)
        for raw in raws {
            #expect(raw.nonzeroBitCount == 1)
        }
    }

    /// The producer unions flags and the consumer asks membership - one round trip of that
    /// shape, with a flag deliberately left out so containment can fail.
    @Test func unionAnswersMembershipWithoutBleeding() {
        let highlight: SquareHighlight = [.lastMove, .check]
        #expect(highlight.contains(.lastMove))
        #expect(highlight.contains(.check))
        #expect(!highlight.contains(.hint))
        #expect(!highlight.contains(.selected))
    }
}
