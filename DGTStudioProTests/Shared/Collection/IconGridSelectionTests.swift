import SwiftUI
import Testing
@testable import DGTStudioPro

/// The icons grids' shared selection grammar (2 Aug 2026 — born in
/// `LibraryIconsView`, extracted when the Players grid became its second
/// host). Nonisolated deliberately: index math and rect normalization, no
/// view rendered.
///
/// **The 6 below stopped being the shipped constant on 7 Aug 2026** and is
/// now just a number these cases are written against. It used to be
/// `CollectionGridMetrics.columnCount`, spelled literally so a metrics change
/// would move the expectations consciously; the count is derived from window
/// width now, so there is no constant to track and the literal is the whole
/// truth. That is a *strengthening* rather than a loss — this suite tests the
/// stepping grammar at an arbitrary width, and `CollectionViewOptionsTests`
/// owns which width yields which count. Two questions, two suites, neither
/// standing in for the other.
struct IconGridSelectionTests {

    private let columns = 6

    // MARK: Arrows

    /// Left/right step reading order, so they wrap across row boundaries —
    /// right from a row's last card lands on the next row's first.
    @Test func horizontalStepsWrapRows() {
        #expect(IconGridSelection.destination(from: 5, direction: .right, columnCount: columns, count: 14) == 6)
        #expect(IconGridSelection.destination(from: 6, direction: .left, columnCount: columns, count: 14) == 5)
    }

    @Test func horizontalStepsClampAtTheEnds() {
        #expect(IconGridSelection.destination(from: 0, direction: .left, columnCount: columns, count: 14) == 0)
        #expect(IconGridSelection.destination(from: 13, direction: .right, columnCount: columns, count: 14) == 13)
    }

    @Test func verticalStepsMoveOneRow() {
        #expect(IconGridSelection.destination(from: 8, direction: .down, columnCount: columns, count: 20) == 14)
        #expect(IconGridSelection.destination(from: 8, direction: .up, columnCount: columns, count: 20) == 2)
    }

    @Test func upHoldsOnTheTopRow() {
        #expect(IconGridSelection.destination(from: 3, direction: .up, columnCount: columns, count: 14) == 3)
    }

    /// Finder's partial-row grammar: down from a card with no cell beneath
    /// it lands on the last card, and down from the last card stays put.
    @Test func downOverflowLandsOnTheLastCard() {
        #expect(IconGridSelection.destination(from: 10, direction: .down, columnCount: columns, count: 14) == 13)
        #expect(IconGridSelection.destination(from: 13, direction: .down, columnCount: columns, count: 14) == 13)
    }

    /// ↓ holds across the *whole* last row, not only on the last card — the
    /// pre-fix formula slid 12 → 13 (6 columns, count 14): a vertical key
    /// performing a horizontal move, asymmetric with `.up`'s hold. This is
    /// the case the original pins missed; both shipped expectations above
    /// are points where the broken formula happened to be right (4 Aug 2026).
    @Test func downHoldsAcrossTheWholeLastRow() {
        #expect(IconGridSelection.destination(from: 12, direction: .down, columnCount: columns, count: 14) == 12)
        // A *full* last row holds too — 12 of 12 at 6 columns has no hole
        // anywhere, and ↓ from its middle must not walk to the corner.
        #expect(IconGridSelection.destination(from: 9, direction: .down, columnCount: columns, count: 12) == 9)
    }

    /// The galleries reuse the grammar as its one-row degenerate case
    /// (`columnCount == count`, 4 Aug 2026): ← / → clamp without wrapping —
    /// a strip has no next row to wrap onto — and ↑ / ↓ hold everywhere.
    /// The ↓ hold is the last-row guard earning its keep a second time: on
    /// the pre-fix formula, ↓ in a one-row strip jumped to the *last* card.
    @Test func aFilmstripIsAOneRowGrid() {
        #expect(IconGridSelection.destination(from: 2, direction: .right, columnCount: 5, count: 5) == 3)
        #expect(IconGridSelection.destination(from: 4, direction: .right, columnCount: 5, count: 5) == 4)
        #expect(IconGridSelection.destination(from: 0, direction: .left,  columnCount: 5, count: 5) == 0)
        #expect(IconGridSelection.destination(from: 2, direction: .up,    columnCount: 5, count: 5) == 2)
        #expect(IconGridSelection.destination(from: 2, direction: .down,  columnCount: 5, count: 5) == 2)
    }

    // MARK: Geometry Stability

    /// The transform-stability rule (the "cycling between duplicate values"
    /// warning's fourth correction, 4 Aug 2026): sub-point wobble must map
    /// to one value at every anchor macOS layout actually rests on —
    /// integers at 1×, halves at 2×. `.integral` failed exactly this:
    /// floor/ceil across 91.0 turned a ±0.0002 wobble into 91 ↔ 92, the
    /// alternation the warning names.
    @Test func stableFrameAbsorbsSubPointWobbleAtRealAnchors() {
        let a = IconGridSelection.stableFrame(
            CGRect(x: 90.9998, y: 10.4999, width: 160.0001, height: 199.9999)
        )
        let b = IconGridSelection.stableFrame(
            CGRect(x: 91.0002, y: 10.5001, width: 159.9999, height: 200.0001)
        )
        #expect(a == b)
        #expect(a == CGRect(x: 91, y: 10.5, width: 160, height: 200))
    }

    // MARK: Rubber Band

    /// All four sweep directions produce the same normalized band — a
    /// drag up-and-left is the mirror of down-and-right, not a negative
    /// rectangle.
    @Test func selectionRectNormalizesEveryQuadrant() {
        let expected = CGRect(x: 10, y: 20, width: 30, height: 40)
        let a = CGPoint(x: 10, y: 20)
        let b = CGPoint(x: 40, y: 60)

        #expect(IconGridSelection.selectionRect(from: a, to: b) == expected)
        #expect(IconGridSelection.selectionRect(from: b, to: a) == expected)
        #expect(IconGridSelection.selectionRect(from: CGPoint(x: 40, y: 20), to: CGPoint(x: 10, y: 60)) == expected)
        #expect(IconGridSelection.selectionRect(from: CGPoint(x: 10, y: 60), to: CGPoint(x: 40, y: 20)) == expected)
    }

    @Test func zeroDragIsAnEmptyBand() {
        let point = CGPoint(x: 5, y: 5)
        let band = IconGridSelection.selectionRect(from: point, to: point)
        #expect(band.isEmpty)
    }
}
