//
//  PieceIdentity.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 02/08/2026.
//

/// One piece the board's piece layer renders: what it is, where it sits, and
/// the identity it animates under.
///
/// M6's currency. `BoardPieceLayer` keys its `ForEach` on `key`, so the whole
/// animation contract lives in how the key is chosen: a **persisting** key
/// whose square changes glides; a key that appears or disappears fades. There
/// is no third behaviour, which is the design — a piece can only glide under
/// an identity somebody proved, because an unproven piece never gets a key
/// that survives the render where it moved.
internal struct ResolvedPiece: Equatable, Hashable, Sendable, Identifiable {

    /// Either a proven tracker identity or a square-bound anonymous one.
    ///
    /// `anonymous` carries the `Piece` as well as the square deliberately: a
    /// square whose occupant is *replaced* while diverged (the capture made
    /// piece-first, say) must produce a fresh key, so the swap renders as a
    /// fade-out/fade-in rather than one piece morphing into its captor —
    /// a morph is the promotion grammar, and only promotion may speak it.
    internal enum Key: Equatable, Hashable, Sendable {
        case tracked(PieceID)
        case anonymous(Square, Piece)
    }

    internal let key: Key
    internal let piece: Piece
    internal let square: Square

    internal var id: Key { key }
}

/// Resolves which identity every rendered piece animates under — the
/// tracker-parity work that `PieceTracker`'s doc spent four months calling
/// "the work that would make the physical mirror safe to animate" (M6).
///
/// **The output's occupancy is the rendered position, verbatim, always.**
/// The resolver decides *keys*, never *presence*: every occupied square of
/// the input position produces exactly one entry, and no unoccupied square
/// produces any. That is the mirror invariant ("the mirror renders the
/// physical board — always") restated as a property of a pure function, and
/// `PieceIdentityTests` pins it across every fixture rather than trusting
/// this sentence.
///
/// **Identity is proven or absent, never guessed.** Three sources, in order:
///
/// 1. **Parity.** A square where the physical piece equals the game's last
///    committed position vouches for the tracker's identity there. Checked
///    per square, not per board, so one lifted piece doesn't strip the other
///    thirty-one of their identities mid-move.
/// 2. **Early reconstruction.** For the squares parity can't explain, the
///    resolver runs the *same* `DGTReconstructor.reconstruct` the session
///    will settle with — full-position verification included — and keys a
///    recognized move's landing square(s) with the **origin's** tracker
///    identity. This is what lets a slid or quickly-played move glide before
///    the session commits it, and it is proof rather than speculation
///    because the reconstructor only answers when exactly one legal move
///    explains the whole board. The session's own commit 300 ms later
///    re-derives the same answer; nothing here touches the game.
/// 3. **Anonymous.** Everything else keys on `(square, piece)` — stable
///    while the piece stays put, incapable of gliding, which is exactly the
///    right amount of capability for a piece nobody can name. A board dump
///    at connect re-keys wholesale, so thirty-two pieces fade in rather
///    than fly in from wherever they last stood.
///
/// Why the identity upgrade at commit is invisible, recorded because it is
/// the detail the whole design balances on: when the session commits the
/// recognized move, `LiveGame`'s tracker applies it — and `applyMove` puts
/// the *origin's* identity on the destination square, which is the identity
/// source 2 already handed out. The key at the proven render and the key at
/// the parity render after the commit are the same value, so the hand-off
/// from "proven early" to "vouched by parity" re-keys nothing and the eye
/// sees one uninterrupted piece.
internal enum PieceIdentity {

    /// The review arm: the rendered position *is* the game's position, so
    /// parity is total and the per-ply tracker vouches for every square.
    /// (`Game` and `LibraryGamePreviewState` both maintain exactly this
    /// pairing; an `.empty` tracker degrades to all-anonymous, which is what
    /// the style previews pass.)
    internal static func resolved(
        position: Position,
        tracker: PieceTracker
    ) -> [ResolvedPiece] {
        Square.all.compactMap { square in
            let piece = position[square]
            guard piece.isOccupied else { return nil }
            let key: ResolvedPiece.Key =
                tracker[square].map(ResolvedPiece.Key.tracked)
                ?? .anonymous(square, piece)
            return ResolvedPiece(key: key, piece: piece, square: square)
        }
    }

    /// The mirror arm: `physical` is what renders (all of it, only it);
    /// `game` and `tracker` are the live game's last committed state and its
    /// identity map, or nil when no game is running — in which case every
    /// piece is anonymous and nothing can glide, matching the pre-M6 mirror
    /// exactly.
    internal static func resolved(
        physical: Position,
        game: GameState?,
        tracker: PieceTracker?
    ) -> [ResolvedPiece] {
        guard let game, let tracker else {
            return resolved(position: physical, tracker: .empty)
        }

        // Source 2, computed once per resolve rather than once per square:
        // cheap (a 64-square diff, one move-generation pass when the diff is
        // non-empty), and only consulted for squares parity couldn't explain.
        let proven = provenPlacements(game: game, physical: physical)

        return Square.all.compactMap { square in
            let piece = physical[square]
            guard piece.isOccupied else { return nil }

            let key: ResolvedPiece.Key
            if game.position[square] == piece, let identity = tracker[square] {
                key = .tracked(identity)
            } else if let placement = proven.first(where: {
                $0.square == square && $0.piece == piece
            }), let identity = tracker[placement.origin] {
                key = .tracked(identity)
            } else {
                key = .anonymous(square, piece)
            }
            return ResolvedPiece(key: key, piece: piece, square: square)
        }
    }

    // MARK: Private Helpers

    /// A square the reconstructor proved a piece just arrived on, with the
    /// square it came from — the origin is what carries the identity.
    private struct Placement {
        internal let square: Square
        internal let piece: Piece
        internal let origin: Square
    }

    /// The landing squares a recognized move explains, or nothing when the
    /// board's divergence isn't (yet) a single legal move.
    ///
    /// `.move` and `.correctable` both prove their move — `.correctable`'s
    /// un-cleared capture square needs no entry here because the game still
    /// has that pawn too, so parity keeps it real until it is lifted.
    /// `.castlingInProgress` proves both landing squares and lets occupancy
    /// decide which of them has landed; the one still airborne matches no
    /// occupied square and the entry goes unread. `.inProgress`,
    /// `.unresolved` and `.noChange` prove nothing, deliberately: a board
    /// mid-thought or mid-desync gets parity and anonymity only.
    private static func provenPlacements(
        game: GameState,
        physical: Position
    ) -> [Placement] {
        switch DGTReconstructor.reconstruct(from: game, physical: physical) {
        case .move(let move), .castlingInProgress(let move),
             .correctable(let move, _, _):
            return placements(for: move)
        case .noChange, .inProgress, .unresolved:
            return []
        }
    }

    /// The move's own landing square — promotion lands the *promoted* piece
    /// under the pawn's identity, `PieceTracker.applyMove`'s exact rule —
    /// plus the rook's for a castle.
    private static func placements(for move: Move) -> [Placement] {
        var result = [
            Placement(
                square: move.to,
                piece: Piece(move.pieceColor, move.promotionType ?? move.pieceType),
                origin: move.from
            )
        ]
        if move.isCastling, let rookFrom = move.rookFrom, let rookTo = move.rookTo {
            result.append(
                Placement(
                    square: rookTo,
                    piece: Piece(move.pieceColor, .rook),
                    origin: rookFrom
                )
            )
        }
        return result
    }
}
