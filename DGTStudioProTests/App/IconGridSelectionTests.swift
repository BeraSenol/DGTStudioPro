//
//  IconGridSelectionTests.swift
//  DGTStudioProTests
//
//  Created by Supreme Leader on 02/08/2026.
//

import SwiftUI
import Testing
@testable import DGTStudioPro

/// The icons grids' shared selection grammar (2 Aug 2026 — born in
/// `LibraryIconsView`, extracted when the Players grid became its second
/// host). Nonisolated deliberately: index math and rect normalization, no
/// view rendered. The 6-column geometry is the shipped
/// `CollectionGridMetrics.columnCount`, spelled literally here so a
/// metrics change moves these expectations consciously.
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
