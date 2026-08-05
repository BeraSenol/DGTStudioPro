import Testing
@testable import DGTStudioPro

/// Table-driven coverage for the M6 diff → instruction formatter: the three
/// verbs (remove / place / replace), the highlight-set split, deterministic
/// a1→h8 ordering, and the live-shrinking behavior the overlay depends on.
/// Pure value types throughout, so the suite runs nonisolated (working
/// agreement: `@MainActor` only where the types demand it).
@Suite("Recovery Guidance — Restore Instructions")
struct RecoveryGuidanceTests {
    
    @Test func matchingBoardsNeedNothing() {
        let guidance = RecoveryGuidance(physical: .starting, target: .starting)
        
        #expect(guidance.isEmpty)
        #expect(guidance.items.isEmpty)
        #expect(guidance.attentionSquares.isEmpty)
        #expect(guidance.targetSquares.isEmpty)
    }
    
    @Test func extraPieceReadsAsRemove() {
        var physical = Position.starting
        physical[Squares.c3] = .whiteKnight     // stray extra piece
        
        let guidance = RecoveryGuidance(physical: physical, target: .starting)
        
        #expect(guidance.items.count == 1)
        #expect(guidance.items.first?.message == "c3 — remove the White Knight")
        #expect(guidance.attentionSquares == [Squares.c3])
        #expect(guidance.targetSquares.isEmpty)
    }
    
    @Test func missingPieceReadsAsPlace() {
        var physical = Position.starting
        physical[Squares.g1] = .empty            // knight lifted off the board
        
        let guidance = RecoveryGuidance(physical: physical, target: .starting)
        
        #expect(guidance.items.count == 1)
        #expect(guidance.items.first?.message == "g1 — place the White Knight")
        #expect(guidance.targetSquares == [Squares.g1])
        #expect(guidance.attentionSquares.isEmpty)
    }
    
    @Test func wrongPieceReadsAsReplace() {
        var target = Position.starting
        target[Squares.e4] = .whiteKnight
        var physical = Position.starting
        physical[Squares.e4] = .blackPawn
        
        let guidance = RecoveryGuidance(physical: physical, target: target)
        
        #expect(guidance.items.count == 1)
        #expect(
            guidance.items.first?.message
            == "e4 — replace the Black Pawn with the White Knight"
        )
        // Wrong-piece squares are attention-only: the instruction text
        // carries what belongs there; stacking both styles reads as noise.
        #expect(guidance.attentionSquares == [Squares.e4])
        #expect(guidance.targetSquares.isEmpty)
    }
    
    /// A realistic desync: the knight physically went to h3 while the game
    /// recorded Nf3 — one place, one remove, sorted by square (a1 → h8).
    @Test func misplacedKnightYieldsPlaceThenRemoveInSquareOrder() {
        var target = Position.starting
        target[Squares.g1] = .empty
        target[Squares.f3] = .whiteKnight
        
        var physical = Position.starting
        physical[Squares.g1] = .empty
        physical[Squares.h3] = .whiteKnight
        
        let guidance = RecoveryGuidance(physical: physical, target: target)
        
        #expect(guidance.items.map(\.message) == [
            "f3 — place the White Knight",
            "h3 — remove the White Knight",
        ])
        #expect(guidance.attentionSquares == [Squares.h3])
        #expect(guidance.targetSquares == [Squares.f3])
    }
    
    /// The whole point of live recomputation: fixing a square shrinks the
    /// list, and restoring the last one empties it (the session's settle
    /// then exits recovery — that transition is covered in the session
    /// suite; this pins the formatter's side of the contract).
    @Test func guidanceShrinksAsSquaresAreFixed() {
        var target = Position.starting
        target[Squares.g1] = .empty
        target[Squares.f3] = .whiteKnight
        
        var physical = Position.starting
        physical[Squares.g1] = .empty
        physical[Squares.h3] = .whiteKnight
        
        #expect(RecoveryGuidance(physical: physical, target: target).items.count == 2)
        
        physical[Squares.h3] = .empty           // player removes the stray knight…
        #expect(RecoveryGuidance(physical: physical, target: target).items.count == 1)
        
        physical[Squares.f3] = .whiteKnight     // …and places it correctly
        #expect(RecoveryGuidance(physical: physical, target: target).isEmpty)
    }
}
