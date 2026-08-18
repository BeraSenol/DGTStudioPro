import SwiftUI
import Testing
@testable import DGTStudioPro

/// The grids' shared selection grammar. Nonisolated: index math and rect normalization.
struct IconGridSelectionTests {

    private let columns = 6

    // MARK: Arrows

    /// Left/right step reading order, so they wrap across row boundaries -
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

    /// ↓ holds across the *whole* last row - the pre-fix formula slid 12 → 13: a vertical key
    /// performing a horizontal move.
    @Test func downHoldsAcrossTheWholeLastRow() {
        #expect(IconGridSelection.destination(from: 12, direction: .down, columnCount: columns, count: 14) == 12)
        // A *full* last row holds too - 12 of 12 at 6 columns has no hole
        // anywhere, and ↓ from its middle must not walk to the corner.
        #expect(IconGridSelection.destination(from: 9, direction: .down, columnCount: columns, count: 12) == 9)
    }

    /// The galleries' one-row degenerate case: ← / → clamp without wrapping, ↑ / ↓ hold everywhere.
    @Test func aFilmstripIsAOneRowGrid() {
        #expect(IconGridSelection.destination(from: 2, direction: .right, columnCount: 5, count: 5) == 3)
        #expect(IconGridSelection.destination(from: 4, direction: .right, columnCount: 5, count: 5) == 4)
        #expect(IconGridSelection.destination(from: 0, direction: .left,  columnCount: 5, count: 5) == 0)
        #expect(IconGridSelection.destination(from: 2, direction: .up,    columnCount: 5, count: 5) == 2)
        #expect(IconGridSelection.destination(from: 2, direction: .down,  columnCount: 5, count: 5) == 2)
    }

    // MARK: Geometry Stability

    /// The transform-stability rule: sub-point wobble maps to one value at every anchor macOS
    /// layout rests on.
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

    /// All four sweep directions produce the same normalized band - a
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

    // MARK: Finder's Subject Rule

    /// Stands in for a card's model - `subjects` needs nothing but identity.
    private struct Item: Identifiable, Equatable {
        let id: Int
    }

    private var items: [Item] { (0..<5).map(Item.init) }

    /// Acting on a card *inside* a multi-selection acts on the whole selection. This is the rule
    /// whose absence was the "select all, delete all, it deletes one" report, and it only became
    /// assertable when it stopped being a private method on a `View` (18 Aug 2026).
    @Test func actingInsideAMultiSelectionTakesTheWholeSelection() {
        let resolved = IconGridSelection.subjects(for: items[1], in: items, selection: [1, 3])
        #expect(resolved == [items[1], items[3]])
    }

    /// Acting on a card *outside* the selection takes only that card - the selection is not
    /// extended, and the untouched cards keep their state.
    @Test func actingOutsideTheSelectionTakesOnlyThatCard() {
        let resolved = IconGridSelection.subjects(for: items[4], in: items, selection: [1, 3])
        #expect(resolved == [items[4]])
    }

    /// A single selection is not a multi-selection: one card in, one card out, whether or not the
    /// card is the selected one.
    @Test func aSingleSelectionResolvesToTheCardItself() {
        #expect(IconGridSelection.subjects(for: items[2], in: items, selection: [2]) == [items[2]])
        #expect(IconGridSelection.subjects(for: items[2], in: items, selection: []) == [items[2]])
    }

    /// **Display order, never set order.** The export door numbers filenames off this array and
    /// the open door makes tabs from it, so a `Set`'s arbitrary order would number them
    /// arbitrarily. Asked for in reverse to make the claim capable of failing.
    @Test func subjectsArriveInDisplayOrder() {
        let resolved = IconGridSelection.subjects(for: items[3], in: items, selection: [3, 0, 2])
        #expect(resolved.map(\.id) == [0, 2, 3])
    }
}
