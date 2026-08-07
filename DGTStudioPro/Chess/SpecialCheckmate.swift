/// A recognised checkmate *pattern*, computed at analysis time and stored on
/// the game (M-lib.4, D19′; vocabulary widened to ten by D65′). Pure
/// `Position`/`GameState` predicates over the final position — no engine, and
/// no last move needed (every recognised pattern is positional; a case that
/// ever needs the mating move gets it threaded then, not speculatively now).
///
/// **Each case is defined so it cannot false-positive on an unrelated mate.**
/// That bar is D19′'s and it survives the widening — it is what makes a stored
/// value mean something. An ordinary mate, and any non-mate, classifies `nil`.
///
/// **The `isCheckmate` guard is load-bearing and shortens every recogniser.**
/// Because `classify` refuses a position that is not mate, a recogniser only
/// has to identify the *configuration* — it never has to re-prove that the
/// flight squares are covered, because they demonstrably are. Where a
/// recogniser still checks a wall (`backRank`, `epaulette`, `gueridon`,
/// `dovetail`) it is not redundancy: it is distinguishing *which* thing did
/// the covering, and "walled by its own men" versus "covered by the enemy"
/// are different motifs wearing the same mate.
///
/// **Raw values are stored.** They ride `PGN.specialCheckmate` and every saved
/// smart tag's rule blob, so *adding* a case is free and *renaming* one is a
/// silent data migration — the D36′ trap, one type over. New cases here take
/// implicit raw values matching their Swift names; that is safe exactly once,
/// at birth.
internal enum SpecialCheckmate: String, Codable, Sendable, CaseIterable {

    // Ordered for a reader, not for the classifier — `allCases` drives the
    // smart-tag picker's menu, and precedence lives in `precedence` below so
    // that reordering this list cannot change what a game classifies as.
    case smothered
    case backRank
    case anastasia
    case arabian
    case opera
    case boden
    case epaulette
    case gueridon
    case dovetail
    case hook

    // MARK: Display

    /// The enum's one user-facing rendering. Consumed by the smart-tag
    /// editor's motif picker, the Library's Checkmate Type column and Get
    /// Info — the seeded "Smothered Mates" tag carries a literal name, so this
    /// is not what keeps the two in step and shouldn't be documented as if it
    /// were.
    ///
    /// **Title case throughout** (5 Aug 2026, by request): "Back Rank", not
    /// "Back rank". These read as the names of things — a reader scanning a
    /// Checkmate Type column sees proper nouns rather than sentence fragments.
    ///
    /// **Diacritics preserved** (D65′): "Épaulette", "Guéridon". These are
    /// French proper names and the app already keeps diacritics deliberately
    /// where a name carries them (D9′'s "Bücher" ≠ "Bucher"). The possessive
    /// forms — "Anastasia's", "Boden's" — carry no trailing "Mate" because the
    /// column header already supplies the noun, which is the same reason
    /// "Smothered" stands alone.
    ///
    /// Deliberately unlocalized, matching the PGN tag labels' recorded stance,
    /// and deliberately *not* `rawValue.capitalized`, which renders `backRank`
    /// as "Backrank" and `epaulette` without its accent. The pin exists to
    /// catch exactly that simplification.
    internal var displayName: String {
        switch self {
        case .smothered: return "Smothered"
        case .backRank:  return "Back Rank"
        case .anastasia: return "Anastasia's"
        case .arabian:   return "Arabian"
        case .opera:     return "Opera"
        case .boden:     return "Boden's"
        case .epaulette: return "Épaulette"
        case .gueridon:  return "Guéridon"
        case .dovetail:  return "Dovetail"
        case .hook:      return "Hook"
        }
    }

    // MARK: Classification

    /// Recognises the checkmate type in `state`, or `nil` when the position is
    /// not checkmate or is an ordinary mate. Self-checking (`isCheckmate`
    /// guarded) so it is total and testable without the analysis driver.
    internal static func classify(_ state: GameState) -> SpecialCheckmate? {
        guard state.isCheckmate else { return nil }

        let mated = state.activeColor          // the side to move is the mated side
        guard let king = state.position.kingSquare(for: mated) else { return nil }
        let context = Context(position: state.position, king: king, mated: mated)

        return precedence.first { $0.matches(context) }
    }

    /// **Precedence, narrowest motif first** (D65′). A mate can honestly fit
    /// two shapes — an Arabian in the corner is also a rook check along a
    /// rank, an Opera mate is a back-rank rook mate with a bishop behind it —
    /// and the stored column holds one value, so the order is the decision.
    ///
    /// Stated as *data* rather than as an `if`-chain on purpose: an order is a
    /// thing a reader should be able to see at a glance, and control flow
    /// hides it among the conditions.
    ///
    /// **Two ways a new case can go wrong here, and only one is caught by the
    /// compiler.** Omitting its recogniser is a build error, because `matches`
    /// switches exhaustively. Omitting it from *this list* is not — it would
    /// simply never classify, silently. The witness for that is
    /// `everyCaseIsProducible`, which asserts that the suite's fixtures
    /// between them yield all ten cases; a case added without a fixture, or
    /// added here but unreachable, turns it red. That is the D40′ rule applied
    /// to an enum: a case nothing can produce is a stored value that can never
    /// appear.
    ///
    /// Most pairs are disjoint by construction and the ordering never fires:
    /// `smothered`'s checker is a knight, `boden`'s a bishop, `gueridon`'s and
    /// `dovetail`'s a queen, so none can collide with the rook/queen motifs.
    /// `anastasia` needs an edge file and `epaulette` needs two on-board rank
    /// neighbours, which an edge-file king cannot have. The four that do
    /// overlap, and why the order is what it is:
    ///
    /// - `arabian` before `hook` — **a tie-break, not a specificity call.**
    ///   Neither is a subset of the other (Arabian adds the corner, Hook adds
    ///   the pawn link), so a corner rook mate whose knight is pawn-defended
    ///   satisfies both. The corner is the stronger visual signature and the
    ///   older name, so it wins. Pinned by `aCornerHookIsCalledArabian`, which
    ///   is the test to change if the call ever changes.
    /// - `arabian` before `anastasia` — a corner king on the h-file can wear
    ///   both; Arabian additionally requires the knight to *defend the rook*,
    ///   which is strictly more constrained.
    /// - `opera` and `epaulette` before `backRank` — both are a back-rank mate
    ///   with a named extra condition, so the broader name goes last.
    private static let precedence: [SpecialCheckmate] = [
        .smothered,
        .arabian,
        .hook,
        .anastasia,
        .opera,
        .boden,
        .gueridon,
        .dovetail,
        .epaulette,
        .backRank,
    ]

    /// One exhaustive switch, so the compiler refuses a new case that nobody
    /// taught to recognise itself. The alternative — an array of
    /// `(motif, closure)` pairs — reads better at the declaration and lets a
    /// case be added with no recogniser at all.
    private func matches(_ context: Context) -> Bool {
        switch self {
        case .smothered: return context.isSmothered
        case .backRank:  return context.isBackRank
        case .anastasia: return context.isAnastasia
        case .arabian:   return context.isArabian
        case .opera:     return context.isOpera
        case .boden:     return context.isBoden
        case .epaulette: return context.isEpaulette
        case .gueridon:  return context.isGueridon
        case .dovetail:  return context.isDovetail
        case .hook:      return context.isHook
        }
    }
}

// MARK: - Context

extension SpecialCheckmate {

    /// The mated king and the board around it, derived once and handed to
    /// every recogniser.
    ///
    /// A struct rather than four parameters threaded through twenty free
    /// functions: `attacker`, `backRank` and `forward` are each a small
    /// derivation off `mated` that every second predicate wants, and computing
    /// them per-predicate is how two spellings of "which way is forward" begin.
    fileprivate struct Context {
        let position: Position
        let king: Square
        let mated: PieceColor

        /// The side that delivered the mate.
        var attacker: PieceColor { mated.opponent }

        /// White's back rank is rank 0 (the 1st rank); Black's is rank 7.
        var backRank: Int { mated == .white ? 0 : 7 }

        /// One rank toward the centre, from the mated king's point of view.
        var forward: Int { mated == .white ? 8 : -8 }
    }
}

// MARK: - Geometry

extension SpecialCheckmate.Context {

    /// A neighbouring square of the king, or nil if the offset walks off the
    /// board or wraps across the a/h seam.
    ///
    /// The wrap guard is not optional decoration: `king + 1` from h4 lands on
    /// a5, which is a legal square and the wrong one. Every offset in this
    /// file goes through here so the guard cannot be forgotten at one site —
    /// the mistake the shared `Square` offsets' own doc warns about.
    func neighbour(_ offset: Int) -> Square? {
        let square = king + offset
        guard square.isOnBoard, abs(square.file - king.file) <= 1 else { return nil }
        return square
    }

    /// Every on-board neighbour of the king.
    var neighbours: [Square] { Square.kingOffsets.compactMap(neighbour) }

    /// The king's four orthogonal neighbours — the squares an adjacent rook
    /// could check from.
    var orthogonalNeighbours: [Square] { Square.rookDirections.compactMap(neighbour) }

    func isFriendly(_ square: Square) -> Bool { position[square].isColor(mated) }

    /// Whether `square` holds a piece of the given type belonging to the
    /// mating side.
    func isEnemy(_ type: PieceType, at square: Square) -> Bool {
        position[square] == Piece(attacker, type)
    }

    /// Every listed offset that lands on the board holds a friendly piece.
    /// **Off-board offsets are walls and do not disqualify** — a king in the
    /// corner boxed by two pawns is still smothered.
    func areFriendlyOrWalled(_ offsets: [Int]) -> Bool {
        offsets.allSatisfy { offset in
            guard let square = neighbour(offset) else { return true }
            return isFriendly(square)
        }
    }

    /// Every listed offset must be **on the board** *and* hold a friendly
    /// piece.
    ///
    /// The strict twin of `areFriendlyOrWalled`, and the distinction is the
    /// whole difference between a smothered king and an épaulette. A wall is a
    /// legitimate part of "boxed in"; it is not a shoulder pad. Without this,
    /// a king on a8 with one friendly piece on b8 reads as flanked on both
    /// sides, because the missing side is off the board.
    func areFriendlyAndOnBoard(_ offsets: [Int]) -> Bool {
        offsets.allSatisfy { offset in
            guard let square = neighbour(offset) else { return false }
            return isFriendly(square)
        }
    }
}

// MARK: - Attack queries

extension SpecialCheckmate.Context {

    /// Whether a mating-side knight attacks `square`. Generalised from the
    /// old `knightGivesCheck`, which only ever asked about the king — four of
    /// the new motifs ask about a *defended piece* or a *flight square*
    /// instead.
    func knightAttacks(_ square: Square) -> Bool {
        position.hasPiece(
            Piece(attacker, .knight),
            steppingFrom: square, offsets: Square.knightOffsets, maxFileDistance: 2
        )
    }

    /// Whether a mating-side pawn attacks `square`. The offsets run *backwards*
    /// from the target — a white pawn attacking `t` stands on `t - 7` or
    /// `t - 9` — which is `isSquareAttacked`'s own convention, borrowed rather
    /// than re-derived.
    func pawnAttacks(_ square: Square) -> Bool {
        position.hasPiece(
            Piece(attacker, .pawn),
            steppingFrom: square,
            offsets: attacker == .white ? [-7, -9] : [7, 9],
            maxFileDistance: 1
        )
    }

    /// Whether a mating-side **bishop** attacks `square` — bishops only, not
    /// queens. Opera's signature is a rook backed by a *bishop*; a
    /// queen-supported back-rank rook is an ordinary back-rank mate, and
    /// widening this to `.queen` would quietly rename half of them.
    func bishopAttacks(_ square: Square) -> Bool {
        Square.bishopDirections.contains {
            position.rayHitsSlider(
                from: square, direction: $0,
                slider1: .bishop, slider2: .bishop,
                attacker: attacker
            )
        }
    }

    /// Whether the mating side defends `square` with anything at all,
    /// including its king. Including the king is correct rather than lax: a
    /// king-supported queen on an adjacent square is the textbook shape both
    /// `gueridon` and `dovetail` are built on.
    func isDefended(_ square: Square) -> Bool {
        position.isSquareAttacked(square, by: attacker)
    }

    /// A mating rook or queen bearing on the king **along the king's own
    /// rank** — the back-rank check.
    var rankSliderGivesCheck: Bool { sliderGivesCheck(along: [1, -1]) }

    /// A mating rook or queen bearing on the king **along the king's own
    /// file** — the frontal check that épaulette and Anastasia's are built on.
    var fileSliderGivesCheck: Bool { sliderGivesCheck(along: [8, -8]) }

    private func sliderGivesCheck(along directions: [Int]) -> Bool {
        directions.contains {
            position.rayHitsSlider(
                from: king, direction: $0,
                slider1: .rook, slider2: .queen,
                attacker: attacker
            )
        }
    }

    /// The square of a mating **rook** standing next to the king. An
    /// orthogonally adjacent rook always checks — there is nothing between —
    /// so no separate check test is needed, and a diagonally adjacent rook
    /// checks nothing, which is why only the four orthogonals are scanned.
    var adjacentCheckingRook: Square? {
        orthogonalNeighbours.first { isEnemy(.rook, at: $0) }
    }

    /// Whether a mating **bishop** gives check, found by walking the king's
    /// diagonals rather than its neighbours: a Boden bishop is usually two or
    /// three squares away. Bishops only — a checking *queen* on a diagonal is
    /// a Dovetail, not a Boden, and the two must not blur.
    var checkingBishopExists: Bool {
        Square.bishopDirections.contains {
            position.rayHitsSlider(
                from: king, direction: $0,
                slider1: .bishop, slider2: .bishop,
                attacker: attacker
            )
        }
    }

    /// A mating **queen** on a square adjacent to the king, with the offset
    /// that reached it. The offset is what separates the two queen motifs —
    /// orthogonal is a Guéridon, diagonal is a Dovetail — so it is returned
    /// rather than recomputed by each caller from the square.
    var adjacentCheckingQueen: (square: Square, offset: Int)? {
        for offset in Square.kingOffsets {
            guard let square = neighbour(offset), isEnemy(.queen, at: square) else { continue }
            return (square, offset)
        }
        return nil
    }
}

// MARK: - Recognisers

extension SpecialCheckmate.Context {

    /// A knight gives check and every on-board square around the king holds
    /// the king's *own* piece (the board edge counts as a wall). The checker
    /// is a knight by definition, so this can never overlap a rook, queen or
    /// bishop motif — which is why it sits first in `precedence` at no cost.
    var isSmothered: Bool {
        knightAttacks(king) && areFriendlyOrWalled(Square.kingOffsets)
    }

    /// The king stands on its own back rank, a rook or queen checks *along*
    /// that rank, and the squares directly in front of the king are walled by
    /// its own pieces.
    ///
    /// Specifically the "trapped behind its own pawns" motif: a back-rank
    /// major-piece mate whose escape squares are covered by the *enemy*
    /// instead is a different motif and returns `nil` here — it may still be
    /// an `opera`, which is why that one is tested first.
    var isBackRank: Bool {
        king.rank == backRank
        && rankSliderGivesCheck
        && areFriendlyOrWalled([forward - 1, forward, forward + 1])
    }

    /// King on an edge file, a rook or queen checking down that file, its own
    /// piece beside it on the inner file, and a knight covering the inner
    /// diagonal escapes. The classic is Kh7 with its g7 pawn, Ne7 covering g8
    /// and g6, and a rook arriving on the h-file.
    ///
    /// The knight is the discriminant. Strip it out and this is any file mate
    /// against a king on the edge; requiring it to cover *both* inner
    /// diagonals is what makes the shape Anastasia's rather than coincidence.
    var isAnastasia: Bool {
        guard king.file == 0 || king.file == 7 else { return false }
        guard fileSliderGivesCheck else { return false }

        let inward = king.file == 0 ? 1 : -1
        guard let beside = neighbour(inward), isFriendly(beside) else { return false }

        // The two inner-file diagonals. One is off the board when the king is
        // in a corner, and the corner form is a real Anastasia's — so absent
        // squares are skipped, but at least one must exist and every one that
        // does must be covered.
        let diagonals = [inward + 8, inward - 8].compactMap(neighbour)
        return !diagonals.isEmpty && diagonals.allSatisfy(knightAttacks)
    }

    /// King in a corner, a rook adjacent to it, and a knight defending that
    /// rook. Kh8, Rh7, Nf6 — the knight covers g8 while the rook covers g7,
    /// and the rook cannot be taken because the knight holds it.
    ///
    /// The knight-defends-rook link is the whole mate: without it the king
    /// simply captures. That is also what makes this narrower than
    /// `anastasia`, which asks only that a knight cover the flights.
    var isArabian: Bool {
        guard (king.file == 0 || king.file == 7) && (king.rank == 0 || king.rank == 7) else {
            return false
        }
        guard let rook = adjacentCheckingRook else { return false }
        return knightAttacks(rook)
    }

    /// A rook beside the king on its own back rank, defended by a bishop
    /// raking a long diagonal. Morphy's Rd8# with Bg5 behind it.
    ///
    /// Adjacency is required deliberately. Without it, any back-rank rook mate
    /// with a bishop somewhere on the board would take this name, and the
    /// motif is specifically the rook the king can see and cannot touch.
    var isOpera: Bool {
        guard king.rank == backRank else { return false }
        guard let rook = adjacentCheckingRook, rook.rank == king.rank else { return false }
        return bishopAttacks(rook)
    }

    /// Two bishops on criss-crossing diagonals against a king boxed by its
    /// own men. One bishop checks; the other covers a flight square.
    ///
    /// **The colour argument is what removes the need to identify which bishop
    /// is which**, and it is worth stating because the code looks under-specified
    /// without it. A bishop checking the king stands on a square of the king's
    /// own colour. The king's *orthogonal* neighbours are all of the opposite
    /// colour, so a bishop attacking one of them is necessarily a different
    /// bishop — the second one, on the crossing diagonal. Asking "is any
    /// orthogonal neighbour attacked by an enemy bishop" is therefore exactly
    /// the crisscross test, with no bookkeeping.
    ///
    /// The self-block requirement is the rest of the motif: Boden's mates the
    /// castled king that its own rook and pawns have hemmed in.
    ///
    /// **The last clause is the one that earns its keep**, and it was added
    /// after measurement rather than by reasoning. Without it — check by a
    /// bishop, a crossing bishop, one friendly neighbour — this fired on 2.2%
    /// of a 1,500-mate sample, roughly five times the rate of any other named
    /// motif, because a middlegame mate that happens to own two bishops
    /// usually has a queen or rook doing the actual work. Requiring *every*
    /// flight to be either self-blocked or bishop-covered says the thing the
    /// motif actually means: the two bishops and the king's own men account
    /// for the whole box, with nothing else helping.
    var isBoden: Bool {
        guard checkingBishopExists else { return false }
        guard orthogonalNeighbours.contains(where: bishopAttacks) else { return false }
        guard neighbours.contains(where: isFriendly) else { return false }
        return neighbours.allSatisfy { isFriendly($0) || bishopAttacks($0) }
    }

    /// The king flanked on its own rank by its own pieces on **both** sides,
    /// checked frontally down the file. The shoulder pads are usually its
    /// rooks after castling has gone wrong.
    ///
    /// Deliberately *not* restricted to the back rank, unlike `backRank`: a
    /// central king pinned between two of its own pieces and checked down the
    /// file is the same motif and reads as one. The flanks must be on the
    /// board (`areFriendlyAndOnBoard`), which is also what keeps this from
    /// colliding with `anastasia` — an edge-file king has only one flank.
    var isEpaulette: Bool {
        areFriendlyAndOnBoard([-1, 1]) && fileSliderGivesCheck
    }

    /// A defended queen adjacent to the king **orthogonally**, with the king's
    /// own pieces on the two squares diagonally behind it — the tail.
    ///
    /// The mirror of `dovetail`, and the pair is defined by the queen's
    /// approach rather than by two independent shape descriptions, because
    /// that is the only difference between them: a queen in front means the
    /// blockers are on the rear diagonals, a queen on a diagonal means they
    /// are on the rear orthogonals.
    var isGueridon: Bool {
        guard let (queen, offset) = adjacentCheckingQueen,
              Square.rookDirections.contains(offset),
              isDefended(queen) else { return false }

        // The two diagonals flanking the rear direction. A vertical rear is
        // flanked horizontally and vice versa: rear -8 gives -9 and -7, rear
        // -1 gives -9 and +7.
        let rear = -offset
        let tails = abs(rear) == 8 ? [rear - 1, rear + 1] : [rear - 8, rear + 8]
        return areFriendlyAndOnBoard(tails)
    }

    /// A defended queen adjacent to the king **diagonally**, with the king's
    /// own pieces on the two squares orthogonally behind it. Cozio's mate.
    var isDovetail: Bool {
        guard let (queen, offset) = adjacentCheckingQueen,
              Square.bishopDirections.contains(offset),
              isDefended(queen) else { return false }

        // A diagonal decomposes into its vertical and horizontal components,
        // and those two components *are* the flanking orthogonals: rear -9
        // splits into -8 and -1, rear -7 into -8 and +1.
        let rear = -offset
        let vertical = rear > 0 ? 8 : -8
        return areFriendlyAndOnBoard([vertical, rear - vertical])
    }

    /// A rook beside the king, defended by a knight, which is itself defended
    /// by a pawn. The three-link chain is the motif and is distinctive enough
    /// that no further condition is needed.
    ///
    /// Note this does **not** require the pawn to block a flight square, which
    /// some statements of the motif add. The standard teaching diagram — Kh8,
    /// Rh7, Nf6, g5 — has the pawn doing nothing but holding the knight, so
    /// requiring it would reject the position the name was learned from.
    var isHook: Bool {
        guard let rook = adjacentCheckingRook else { return false }
        guard let knight = defendingKnight(of: rook) else { return false }
        return pawnAttacks(knight)
    }

    /// The square of a mating knight defending `square`. `knightAttacks`
    /// answers the yes/no; the hook needs the knight's square so it can ask
    /// what defends *it*, which is the third link.
    private func defendingKnight(of square: Square) -> Square? {
        for offset in Square.knightOffsets {
            let from = square + offset
            guard from.isOnBoard, abs(from.file - square.file) <= 2 else { continue }
            if isEnemy(.knight, at: from) { return from }
        }
        return nil
    }
}
