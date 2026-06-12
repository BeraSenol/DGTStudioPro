//
//  DGTSessionRecordingTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Coverage for the **pure replay analysis** on `DGTSessionRecording` —
/// `settledBoards(quiescence:)` and `reconstructions(from:quiescence:)`. These
/// recompute the live session's 300 ms debounce and move reconstruction from a
/// recorded timestamp stream, deterministically and with no waiting, so a real
/// captured game can be regression-tested (and the quiescence window re-tuned)
/// offline.
///
/// The recorder (`DGTSessionRecorder`, `@MainActor`) is exercised separately in
/// `DGTSessionRecorderTests`; everything here is a value-type computation, so —
/// like the chess and reconstruction suites — it is not `@MainActor`.
///
/// Two behaviours get the most scrutiny because the live session depends on
/// them exactly: the debounce boundary is `>=` (a gap *equal* to the quiescence
/// keeps the earlier board), and state advances **only** on a committed
/// `.move` — `.castlingInProgress` and `.correctable` do not advance, because
/// the completing `.move` lands on a later settled snapshot.
@Suite("DGT Session Recording")
struct DGTSessionRecordingTests {
    
    // MARK: Helpers
    
    private func entry(_ ms: Int, _ board: Position) -> DGTSessionRecording.Entry {
        .init(offsetMillis: ms, board: board)
    }
    
    /// A trivial distinct board: a single piece on one square. Content is
    /// irrelevant to `settledBoards` (which keys purely off timestamps); these
    /// just need to be distinguishable.
    private func marker(_ square: Square, _ piece: Piece = .whiteRook) -> Position {
        Position.make { $0[square] = piece }
    }
    
    /// `before` with the given squares emptied — a "piece in hand" snapshot.
    private func lifting(_ board: Position, _ squares: Square...) -> Position {
        var position = board
        for square in squares { position[square] = .empty }
        return position
    }
    
    /// The unique legal move with these coordinates, for building expectations.
    private func legalMove(
        _ state: GameState,
        from: Square,
        to: Square,
        promotion: PieceType? = nil
    ) throws -> Move {
        try #require(
            DGTReconstructor.move(from: from, to: to, promotion: promotion, in: state),
            "Expected a legal move \(from)→\(to)"
        )
    }
    
    // MARK: settledBoards — Boundaries
    
    @Test func emptyRecordingSettlesToNothing() {
        let recording = DGTSessionRecording(entries: [])
        #expect(recording.settledBoards().isEmpty)
    }
    
    @Test func singleEntryAlwaysSettles() {
        let only = marker(Squares.a1)
        let recording = DGTSessionRecording(entries: [entry(0, only)])
        #expect(recording.settledBoards() == [only])
    }
    
    /// The boundary is `>=`: a gap *exactly* one quiescence long keeps the
    /// earlier board. Pinned at the default 300 ms.
    @Test func gapEqualToQuiescenceKeepsTheEarlierBoard() {
        let a = marker(Squares.a1)
        let b = marker(Squares.b1)
        let recording = DGTSessionRecording(entries: [entry(0, a), entry(300, b)])
        #expect(recording.settledBoards() == [a, b])
    }
    
    /// One millisecond short of quiescence drops the earlier board (the later
    /// one survives as the final snapshot).
    @Test func gapBelowQuiescenceDropsTheEarlierBoard() {
        let a = marker(Squares.a1)
        let b = marker(Squares.b1)
        let recording = DGTSessionRecording(entries: [entry(0, a), entry(299, b)])
        #expect(recording.settledBoards() == [b])
    }
    
    /// A realistic burst of mid-move flicker followed by a pause: only the
    /// boards trailed by a long-enough quiet gap (and the final one) survive.
    @Test func realisticBurstKeepsOnlySettledStates() {
        let a = marker(Squares.a1)   // 0,   gap 40  → dropped
        let b = marker(Squares.b1)   // 40,  gap 50  → dropped
        let c = marker(Squares.c1)   // 90,  gap 360 → kept
        let d = marker(Squares.d1)   // 450, last    → kept
        let recording = DGTSessionRecording(entries: [
            entry(0, a), entry(40, b), entry(90, c), entry(450, d),
        ])
        #expect(recording.settledBoards() == [c, d])
    }
    
    /// The quiescence window is tunable: the same recording settles differently
    /// at different thresholds. A 250 ms gap is transient at 300 ms but settled
    /// at 200 ms.
    @Test func quiescenceIsTunable() {
        let a = marker(Squares.a1)
        let b = marker(Squares.b1)
        let recording = DGTSessionRecording(entries: [entry(0, a), entry(250, b)])
        
        #expect(recording.settledBoards(quiescence: .milliseconds(300)) == [b])
        #expect(recording.settledBoards(quiescence: .milliseconds(200)) == [a, b])
    }
    
    // MARK: reconstructions — Full Replay
    
    /// A three-move opening (1.e4 e5 2.Nf3) recorded with mid-move lift
    /// transients at sub-quiescence gaps and settled boards at long gaps.
    /// Reconstruction must drop the transients and resolve exactly the three
    /// moves, advancing the game state across each so the next move resolves
    /// against the correct position.
    @Test func replaysAThreeMoveOpening() throws {
        let start = GameState.starting
        
        let m1 = try legalMove(start, from: Squares.e2, to: Squares.e4)
        let s1 = start.applying(m1)
        let m2 = try legalMove(s1, from: Squares.e7, to: Squares.e5)
        let s2 = s1.applying(m2)
        let m3 = try legalMove(s2, from: Squares.g1, to: Squares.f3)
        let s3 = s2.applying(m3)
        
        let board1 = s1.position
        let board2 = s2.position
        let board3 = s3.position
        
        let recording = DGTSessionRecording(entries: [
            entry(0,   start.position),                 // gap 40  → dropped
            entry(40,  lifting(start.position, Squares.e2)), // gap 50  → dropped
            entry(90,  board1),                         // gap 360 → SETTLED
            entry(450, lifting(board1, Squares.e7)),    // gap 50  → dropped
            entry(500, board2),                         // gap 400 → SETTLED
            entry(900, lifting(board2, Squares.g1)),    // gap 50  → dropped
            entry(950, board3),                         // last    → SETTLED
        ])
        
        let steps = recording.reconstructions(from: start)
        
        #expect(steps.map(\.outcome) == [.move(m1), .move(m2), .move(m3)])
        #expect(steps.map(\.board) == [board1, board2, board3])
    }
    
    /// `.castlingInProgress` does not advance the game: from the king-moved-but-
    /// rook-still-home interim, then the completed castle, the walk reports the
    /// in-progress ghost first and commits the castle only on the second
    /// settled board (both reconstructed against the *same* pre-castle state).
    @Test func castlingInProgressDoesNotAdvanceState() throws {
        let state = try GameState.parsing("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
        let castle = try legalMove(state, from: Squares.e1, to: Squares.g1)
        #expect(castle.isCastling)
        
        // King has moved e1→g1; the h1 rook is still on its home square.
        let kingMovedOnly: Position = {
            var p = state.position
            p[Squares.e1] = .empty
            p[Squares.g1] = .whiteKing
            return p
        }()
        let fullyCastled = state.position.applying(castle)
        
        let recording = DGTSessionRecording(entries: [
            entry(0,   kingMovedOnly),   // gap 400 → settled
            entry(400, fullyCastled),    // last    → settled
        ])
        
        let steps = recording.reconstructions(from: state)
        #expect(steps.map(\.outcome) == [.castlingInProgress(castle), .move(castle)])
    }
    
    /// `.correctable` does not advance the game either: the EP-without-lifting
    /// slip surfaces as a correctable nudge, and the completing `.move` lands
    /// only once the victim pawn is cleared — both reconstructed against the
    /// same pre-move state.
    @Test func correctableEnPassantDoesNotAdvanceState() throws {
        let state = try GameState.parsing("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        let ep = try legalMove(state, from: Squares.e5, to: Squares.d6)
        #expect(ep.isEnPassant)
        
        // Attacker on d6 but the captured d5 pawn never lifted.
        let uncorrected: Position = {
            var p = state.position
            p[Squares.e5] = .empty
            p[Squares.d6] = .whitePawn
            return p
        }()
        let corrected = state.position.applying(ep)   // d5 victim now cleared
        
        let recording = DGTSessionRecording(entries: [
            entry(0,   uncorrected),   // gap 400 → settled
            entry(400, corrected),     // last    → settled
        ])
        
        let steps = recording.reconstructions(from: state)
        #expect(steps.map(\.outcome) == [
            .correctable(move: ep, clear: [Squares.d5], expectedAfter: corrected),
            .move(ep),
        ])
    }
    
    // MARK: Codable
    
    /// A recording survives the JSON round-trip used by the export/import path.
    /// `jsonData()` encodes dates as ISO-8601, which truncates sub-second
    /// precision — so the fixture uses a whole-second `recordedAt`, the only
    /// values that round-trip to an exact `==`.
    @Test func jsonRoundTripPreservesRecording() throws {
        let recording = DGTSessionRecording(
            identity: .init(serialNumber: "DGT-123", version: "1.0", trademark: "DGT"),
            recordedAt: Date(timeIntervalSince1970: 1_700_000_000),
            entries: [entry(0, .starting), entry(250, marker(Squares.e4, .whitePawn))]
        )
        
        let data = try recording.jsonData()
        let restored = try DGTSessionRecording.decoded(from: data)
        
        #expect(restored == recording)
    }
    
    @Test func decodingMalformedDataThrows() {
        let garbage = Data("not a recording".utf8)
        #expect(throws: (any Error).self) {
            _ = try DGTSessionRecording.decoded(from: garbage)
        }
    }
}
