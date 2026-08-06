import Testing
@testable import DGTStudioPro

/// Pins for M6's identity resolver — pure value types in, pure values out,
/// so the suite is nonisolated by the standing agreement.
///
/// The one property asserted *everywhere*, via `verified(_:against:)`: the
/// resolver's output occupancy is the rendered position, verbatim — "the
/// mirror renders the physical board, always" as a checkable fact rather
/// than a doc sentence. Every fixture below routes through that helper, so a
/// future arm that invents or drops a piece fails a dozen tests at once
/// rather than passing the one that happened not to look.
struct PieceIdentityTests {

    // MARK: Helpers

    /// Plays `sans` from the start, keeping state and tracker in lockstep —
    /// the same pairing `Game`, `LiveGame` and `LibraryGamePreviewState`
    /// maintain.
    private func played(
        _ sans: [String]
    ) throws -> (state: GameState, tracker: PieceTracker) {
        var state = GameState.starting
        var tracker = PieceTracker.starting
        for san in sans {
            let move = try state.parseSAN(san)
            tracker.applyMove(move)
            state = state.applying(move)
        }
        return (state, tracker)
    }

    /// Asserts the resolver's two structural guarantees — occupancy equals
    /// the rendered position exactly, and keys are unique (the layer's
    /// `ForEach` requirement) — then hands the entries back for the
    /// fixture's own assertions.
    @discardableResult
    private func verified(
        _ resolved: [ResolvedPiece],
        against position: Position
    ) -> [Square: ResolvedPiece] {
        var bySquare: [Square: ResolvedPiece] = [:]
        for entry in resolved {
            #expect(bySquare[entry.square] == nil, "two entries on one square")
            bySquare[entry.square] = entry
        }
        for square in Square.all {
            let piece = position[square]
            if piece.isOccupied {
                #expect(bySquare[square]?.piece == piece)
            } else {
                #expect(bySquare[square] == nil)
            }
        }
        #expect(Set(resolved.map(\.key)).count == resolved.count)
        return bySquare
    }

    // MARK: Review Arm

    @Test func theReviewArmTracksEveryOccupiedSquare() throws {
        let (state, tracker) = try played(["e4", "e5", "Nf3"])
        let resolved = PieceIdentity.resolved(
            position: state.position, tracker: tracker
        )
        let bySquare = verified(resolved, against: state.position)
        for entry in bySquare.values {
            guard case .tracked = entry.key else {
                Issue.record("anonymous piece on the review board at \(entry.square)")
                return
            }
        }
        // The knight that moved is the g1 knight, wherever it stands now.
        #expect(bySquare[Squares.f3]?.key == .tracked(PieceTracker.starting[Squares.g1]!))
    }

    @Test func anEmptyTrackerDegradesToAnonymousWithoutLosingAnyPiece() {
        let resolved = PieceIdentity.resolved(position: .starting, tracker: .empty)
        let bySquare = verified(resolved, against: .starting)
        #expect(bySquare.values.allSatisfy {
            if case .anonymous = $0.key { true } else { false }
        })
    }

    // MARK: Mirror Arm — parity

    @Test func parityKeepsEveryIdentityWhenPhysicalMatchesTheGame() throws {
        let (state, tracker) = try played(["e4", "c5"])
        let resolved = PieceIdentity.resolved(
            physical: state.position, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: state.position)
        #expect(bySquare.values.allSatisfy {
            if case .tracked = $0.key { true } else { false }
        })
    }

    @Test func aLiftedPieceDisappearsAndStripsNoNeighbour() throws {
        let (state, tracker) = try played(["e4", "e5"])
        var physical = state.position
        physical[Squares.g1] = .empty   // knight in hand

        let resolved = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: physical)
        #expect(bySquare[Squares.g1] == nil)
        // Everyone still on the board keeps a real identity — per-square
        // parity, not per-board.
        #expect(bySquare.values.allSatisfy {
            if case .tracked = $0.key { true } else { false }
        })
        // And the lifted knight's identity is nowhere: gone with the piece.
        let liftedID = ResolvedPiece.Key.tracked(PieceTracker.starting[Squares.g1]!)
        #expect(!bySquare.values.contains { $0.key == liftedID })
    }

    @Test func aBoardWithNoGameIsWhollyAnonymous() {
        let resolved = PieceIdentity.resolved(
            physical: .starting, game: nil, tracker: nil
        )
        let bySquare = verified(resolved, against: .starting)
        #expect(bySquare.values.allSatisfy {
            if case .anonymous = $0.key { true } else { false }
        })
    }

    // MARK: Mirror Arm — the proven move

    @Test func aCompletedMoveCarriesTheOriginIdentityBeforeTheCommit() throws {
        let (state, tracker) = try played([])
        let move = try state.parseSAN("e4")
        let physical = state.applying(move).position   // board leads the game

        let resolved = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: physical)
        #expect(bySquare[Squares.e4]?.key == .tracked(tracker[Squares.e2]!))
    }

    /// The hand-off the whole design balances on: the identity handed out by
    /// early reconstruction is the identity parity vouches for after the
    /// session commits — same key, no re-key, one uninterrupted piece.
    @Test func theProvenIdentityIsStableAcrossTheCommit() throws {
        var (state, tracker) = try played(["e4", "e5"])
        let move = try state.parseSAN("Nf3")
        let physical = state.applying(move).position

        let before = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let keyBeforeCommit = try #require(
            verified(before, against: physical)[Squares.f3]?.key
        )

        tracker.applyMove(move)
        state = state.applying(move)
        let after = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let keyAfterCommit = try #require(
            verified(after, against: physical)[Squares.f3]?.key
        )

        #expect(keyBeforeCommit == keyAfterCommit)
    }

    @Test func promotionLandsTheNewPieceUnderThePawnsIdentity() throws {
        let (state, tracker) = try played(
            ["e4", "d5", "e5", "f5", "exf6", "Nh6", "fxg7", "Nc6"]
        )
        let move = try state.parseSAN("gxh8=Q")
        let physical = state.applying(move).position

        let resolved = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: physical)
        #expect(bySquare[Squares.h8]?.piece == .whiteQueen)
        #expect(bySquare[Squares.h8]?.key == .tracked(tracker[Squares.g7]!))
    }

    @Test func aCompletedCastleProvesBothPlacements() throws {
        let (state, tracker) = try played(
            ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"]
        )
        let move = try state.parseSAN("O-O")
        let physical = state.applying(move).position

        let resolved = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: physical)
        #expect(bySquare[Squares.g1]?.key == .tracked(tracker[Squares.e1]!))
        #expect(bySquare[Squares.f1]?.key == .tracked(tracker[Squares.h1]!))
    }

    @Test func aMidCastleKingIsProvenWhileTheRookKeepsParity() throws {
        let (state, tracker) = try played(
            ["e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5"]
        )
        var physical = state.position
        physical[Squares.e1] = .empty
        physical[Squares.g1] = .whiteKing   // rook still on h1

        let resolved = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: physical)
        #expect(bySquare[Squares.g1]?.key == .tracked(tracker[Squares.e1]!))
        #expect(bySquare[Squares.h1]?.key == .tracked(tracker[Squares.h1]!))
    }

    @Test func theCorrectableEnPassantProvesTheMoverAndKeepsTheUnliftedPawnReal() throws {
        let (state, tracker) = try played(["e4", "d5", "e5", "f5"])
        var physical = state.position
        physical[Squares.e5] = .empty
        physical[Squares.f6] = .whitePawn   // captured f5 pawn not yet lifted

        let resolved = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: physical)
        #expect(bySquare[Squares.f6]?.key == .tracked(tracker[Squares.e5]!))
        #expect(bySquare[Squares.f5]?.key == .tracked(tracker[Squares.f5]!))
    }

    // MARK: Mirror Arm — the mis-key guard

    /// The failure the old mirror doc feared, pinned shut: a square whose
    /// physical piece disagrees with the game's never inherits the stale
    /// identity — not even under negationless parity, not even when the
    /// board is otherwise untouched.
    @Test func aForeignPieceNeverInheritsTheSquaresOldIdentity() throws {
        let (state, tracker) = try played(["e4", "d5"])
        var physical = state.position
        physical[Squares.d5] = .whiteQueen   // no legal move explains this

        let resolved = PieceIdentity.resolved(
            physical: physical, game: state, tracker: tracker
        )
        let bySquare = verified(resolved, against: physical)
        #expect(
            bySquare[Squares.d5]?.key
            == .anonymous(Squares.d5, .whiteQueen)
        )
    }
}
