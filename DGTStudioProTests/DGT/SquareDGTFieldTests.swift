//
//  SquareDGTFieldTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import Testing
@testable import DGTStudioPro

/// Pins the `a8 ↔ a1` coordinate transform that lives at the DGT decode
/// boundary. The DGT board numbers fields a8 = 0 … h1 = 63; the app uses
/// a1 = 0 … h8 = 63. A single off-by-one here would flip the board top-for-
/// bottom on every dump and silently mis-place every field update, so the
/// corners, the full bijection, and the round-trip are all stated explicitly.
@Suite("Square ↔ DGT Field Transform")
struct SquareDGTFieldTests {
    
    // MARK: Anchored Corners
    
    /// Hand-stated mappings, independent of the formula under test.
    private static let corners: [(field: Int, square: Square)] = [
        (0,  Squares.a8),   // top-left, connector on the left
        (7,  Squares.h8),
        (8,  Squares.a7),
        (56, Squares.a1),
        (63, Squares.h1),   // bottom-right
    ]
    
    @Test func knownCornersMapCorrectly() throws {
        for corner in Self.corners {
            let square = try #require(Square(dgtField: corner.field))
            #expect(
                square == corner.square,
                "DGT field \(corner.field) → \(square), expected \(corner.square)"
            )
        }
    }
    
    @Test func inverseMapsCornersBack() {
        for corner in Self.corners {
            #expect(
                corner.square.dgtField == corner.field,
                "square \(corner.square).dgtField → \(corner.square.dgtField), expected \(corner.field)"
            )
        }
    }
    
    // MARK: Bijection & Round-Trip
    
    @Test func everyFieldMapsToADistinctSquare() {
        let squares = (0..<Square.count).compactMap { Square(dgtField: $0) }
        #expect(squares.count == Square.count)
        #expect(Set(squares).count == Square.count, "transform is not injective")
        #expect(Set(squares) == Set(Square.all), "transform does not cover all squares")
    }
    
    @Test func fieldToSquareToFieldRoundTrips() throws {
        for field in 0..<Square.count {
            let square = try #require(Square(dgtField: field))
            #expect(square.dgtField == field)
        }
    }
    
    @Test func squareToFieldToSquareRoundTrips() {
        for square in Square.all {
            #expect(Square(dgtField: square.dgtField) == square)
        }
    }
    
    // MARK: Range Guards
    
    @Test func outOfRangeFieldsReturnNil() {
        #expect(Square(dgtField: -1) == nil)
        #expect(Square(dgtField: 64) == nil)
        #expect(Square(dgtField: 999) == nil)
    }
}
