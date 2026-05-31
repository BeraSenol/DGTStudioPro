//
//  LibraryGamePreviewStateTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 10/05/2026.
//

import Testing
@testable import DGTStudioPro

@Suite("Library Game Preview State")
struct LibraryGamePreviewStateTests {
    
    // MARK: Empty
    
    @Test func emptyMovesProducesStartingState() {
        let preview = LibraryGamePreviewState.compute(from: [])
        
        #expect(preview.position == .starting)
        #expect(preview.lastMove == nil)
        #expect(preview.checkSquare == nil)
    }
    
    // MARK: Position & Last Move
    
    @Test func singleMovePopulatesPositionAndLastMove() {
        let preview = LibraryGamePreviewState.compute(from: ["e4"])
        
        #expect(preview.position[Squares.e4] == .whitePawn)
        #expect(preview.position[Squares.e2] == .empty)
        #expect(preview.lastMove == LastMove(from: Squares.e2, to: Squares.e4))
    }
    
    @Test func lastMovePointsAtMostRecentMove() {
        let preview = LibraryGamePreviewState.compute(from: ["e4", "e5", "Nf3"])
        
        #expect(preview.lastMove == LastMove(from: Squares.g1, to: Squares.f3))
    }
    
    // MARK: Check Square
    
    @Test func quietGameHasNoCheckSquare() {
        let preview = LibraryGamePreviewState.compute(from: ["e4", "e5", "Nf3"])
        #expect(preview.checkSquare == nil)
    }
    
    @Test func checkmatePopulatesCheckSquareWithKingPosition() {
        // Scholar's Mate: black king on e8 ends in mate.
        let moves = ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"]
        let preview = LibraryGamePreviewState.compute(from: moves)
        
        #expect(preview.checkSquare == Squares.e8)
    }
    
    // MARK: Piece Tracker
    
    @Test func trackerFollowsPieceIdentityThroughMoves() {
        // The pawn that started on e2 should retain its PieceID at e4.
        let originalID = PieceTracker.starting[Squares.e2]
        #expect(originalID != nil)
        
        let preview = LibraryGamePreviewState.compute(from: ["e4"])
        
        #expect(preview.pieceTracker[Squares.e2] == nil)
        #expect(preview.pieceTracker[Squares.e4] == originalID)
    }
    
    @Test func trackerHandlesCastling() {
        // After 1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. O-O,
        // the king ID should now be on g1 and the rook ID on f1.
        let kingID = PieceTracker.starting[Squares.e1]
        let rookID = PieceTracker.starting[Squares.h1]
        
        let preview = LibraryGamePreviewState.compute(
            from: ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "O-O"]
        )
        
        #expect(preview.pieceTracker[Squares.g1] == kingID)
        #expect(preview.pieceTracker[Squares.f1] == rookID)
        #expect(preview.pieceTracker[Squares.e1] == nil)
        #expect(preview.pieceTracker[Squares.h1] == nil)
    }
    
    // MARK: Graceful Fallback
    
    @Test func malformedMoveStopsWalkButReturnsPartialState() {
        // First two moves succeed; the third fails. Preview should reflect
        // the state after the second successful move, not throw.
        let preview = LibraryGamePreviewState.compute(from: ["e4", "e5", "ZZZ"])
        
        #expect(preview.position[Squares.e4] == .whitePawn)
        #expect(preview.position[Squares.e5] == .blackPawn)
        #expect(preview.lastMove == LastMove(from: Squares.e7, to: Squares.e5))
    }
    
    @Test func malformedFirstMoveReturnsStartingState() {
        let preview = LibraryGamePreviewState.compute(from: ["ZZZ"])
        
        #expect(preview.position == .starting)
        #expect(preview.lastMove == nil)
        #expect(preview.checkSquare == nil)
    }
    
    @Test func startingStaticMatchesEmptyCompute() {
        // The `.starting` constant is meant to be equivalent to computing
        // from an empty move list — sanity check.
        let computed = LibraryGamePreviewState.compute(from: [])
        #expect(computed == LibraryGamePreviewState.starting)
    }
}
