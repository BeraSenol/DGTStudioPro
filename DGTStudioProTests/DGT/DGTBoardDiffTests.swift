import Testing
@testable import DGTStudioPro

/// Coverage for `DGTBoardDiff` — the literal before/after delta the
/// reconstruction engine (and, later, the D6 recovery system) reads to decide
/// what happened on the physical board. The type says nothing about legality;
/// these tests pin its *shape* contract, especially the two subtleties the
/// reconstructor leans on:
///
///   1. A capture **destination** belongs to `placed`, never `vacated` — the
///      captured piece leaves no `vacated` trace, because that square ends up
///      occupied (by the mover).
///   2. An en-passant capture whose victim wasn't lifted produces a diff that
///      is *byte-for-byte identical* to a plain pawn push. This is exactly why
///      `DGTReconstructor` needs its `.correctable` near-miss branch — the diff
///      alone cannot tell the two apart.
///
/// `DGTBoardDiff` had no dedicated suite; it was only exercised indirectly
/// through the reconstructor. Not `@MainActor`: the type is a plain value
/// (`Equatable`) whose synthesized `==` is nonisolated, matching every other
/// pure-value suite in the module.
@Suite("DGT Board Diff")
struct DGTBoardDiffTests {

    // MARK: Empty

    /// Identical positions produce an empty diff in every accessor.
    @Test func identicalPositionsProduceEmptyDiff() {
        let diff = DGTBoardDiff(from: .starting, to: .starting)
        #expect(diff.isEmpty)
        #expect(diff.vacated.isEmpty)
        #expect(diff.placed.isEmpty)
        #expect(diff.changedSquares.isEmpty)
    }

    // MARK: Pure Removal / Pure Addition

    /// A square going occupied → empty records the lifted piece in `vacated`
    /// and touches nothing in `placed`.
    @Test func pureRemovalGoesToVacated() {
        let before = Position.make { $0[Squares.e4] = .whitePawn }
        let diff = DGTBoardDiff(from: before, to: .empty)

        #expect(diff.vacated == [Squares.e4: .whitePawn])
        #expect(diff.placed.isEmpty)
        #expect(diff.changedSquares == [Squares.e4])
    }

    /// A square going empty → occupied records the new piece in `placed` and
    /// touches nothing in `vacated`.
    @Test func pureAdditionGoesToPlaced() {
        let after = Position.make { $0[Squares.e4] = .whitePawn }
        let diff = DGTBoardDiff(from: .empty, to: after)

        #expect(diff.placed == [Squares.e4: .whitePawn])
        #expect(diff.vacated.isEmpty)
        #expect(diff.changedSquares == [Squares.e4])
    }

    // MARK: Quiet Move

    /// A quiet move splits across both maps: the origin is vacated, the
    /// destination is placed.
    @Test func quietMoveSplitsAcrossVacatedAndPlaced() {
        let before = Position.make { $0[Squares.e2] = .whitePawn }
        let after  = Position.make { $0[Squares.e4] = .whitePawn }
        let diff = DGTBoardDiff(from: before, to: after)

        #expect(diff.vacated == [Squares.e2: .whitePawn])
        #expect(diff.placed  == [Squares.e4: .whitePawn])
        #expect(diff.changedSquares == [Squares.e2, Squares.e4])
    }

    // MARK: Capture

    /// The defining subtlety: a capture destination (enemy → mover) lands only
    /// in `placed`. The captured piece leaves **no** `vacated` entry — the
    /// square it died on is still occupied afterwards. (Geometry is irrelevant
    /// here; the diff is a literal delta.)
    @Test func captureDestinationGoesToPlacedOnly() {
        let before = Position.make {
            $0[Squares.e4] = .whitePawn
            $0[Squares.d5] = .blackPawn
        }
        // exd5: the white pawn lands on d5, the black pawn is gone, e4 emptied.
        let after = Position.make { $0[Squares.d5] = .whitePawn }
        let diff = DGTBoardDiff(from: before, to: after)

        #expect(diff.vacated == [Squares.e4: .whitePawn])
        #expect(diff.placed  == [Squares.d5: .whitePawn])
        // The captured pawn is invisible to the diff — d5 is in `placed`, never `vacated`.
        #expect(diff.vacated[Squares.d5] == nil)
        #expect(diff.changedSquares == [Squares.e4, Squares.d5])
    }

    // MARK: Castling Footprint

    /// A completed castle is a four-square footprint: the king and the rook
    /// each appear once in `vacated` (origin) and once in `placed` (destination).
    @Test func castlingFootprintHasFourChangedSquares() {
        let before = Position.make {
            $0[Squares.e1] = .whiteKing
            $0[Squares.h1] = .whiteRook
        }
        let after = Position.make {
            $0[Squares.g1] = .whiteKing
            $0[Squares.f1] = .whiteRook
        }
        let diff = DGTBoardDiff(from: before, to: after)

        #expect(diff.vacated == [Squares.e1: .whiteKing, Squares.h1: .whiteRook])
        #expect(diff.placed  == [Squares.g1: .whiteKing, Squares.f1: .whiteRook])
        #expect(diff.changedSquares == [Squares.e1, Squares.h1, Squares.g1, Squares.f1])
    }

    // MARK: En Passant Indistinguishability

    /// An en-passant capture whose victim was **not** lifted produces the exact
    /// same diff as a plain pawn push to the EP target: the victim's square is
    /// unchanged (occupied before, occupied after), so it never enters the diff.
    /// This is the precise reason `DGTReconstructor` cannot rely on the diff
    /// alone and adds the `.correctable` branch — pinned here so the assumption
    /// can't silently rot.
    @Test func uncorrectedEnPassantIsIndistinguishableFromAPlainPush() {
        // A plain (illegal-but-irrelevant) push e5→d6, no neighbour pawn.
        let pushDiff = DGTBoardDiff(
            from: Position.make { $0[Squares.e5] = .whitePawn },
            to:   Position.make { $0[Squares.d6] = .whitePawn }
        )

        // The EP-uncorrected board: attacker on d6, the d5 victim still present.
        let epDiff = DGTBoardDiff(
            from: Position.make {
                $0[Squares.e5] = .whitePawn
                $0[Squares.d5] = .blackPawn
            },
            to: Position.make {
                $0[Squares.d6] = .whitePawn
                $0[Squares.d5] = .blackPawn   // victim never lifted
            }
        )

        #expect(epDiff == pushDiff)
        #expect(epDiff.vacated[Squares.d5] == nil)
        #expect(epDiff.placed[Squares.d5] == nil)
    }

    // MARK: Accessor Consistency

    /// `changedSquares` is exactly the union of the two maps' keys, and
    /// `isEmpty` agrees with it. Driven by a real applied move so the maps are
    /// genuinely populated.
    @Test func changedSquaresIsUnionOfKeysAndDrivesIsEmpty() {
        let push = Move.make(
            from: Squares.e2, to: Squares.e4,
            pieceType: .pawn, pieceColor: .white,
            isDoublePawnPush: true
        )
        let diff = DGTBoardDiff(from: .starting, to: Position.starting.applying(push))

        #expect(diff.changedSquares == Set(diff.vacated.keys).union(diff.placed.keys))
        #expect(diff.changedSquares == [Squares.e2, Squares.e4])
        #expect(diff.isEmpty == false)
    }
}
