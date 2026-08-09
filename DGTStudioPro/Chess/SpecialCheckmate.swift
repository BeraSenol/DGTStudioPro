/// A recognised checkmate pattern, computed at analysis time and stored (D19′; ten cases, D65′).
/// Pure predicates over the final position — no engine, no last move needed. Each case is
/// defined so it cannot false-positive on an unrelated mate; the `isCheckmate` guard in
/// `classify` is load-bearing — recognisers only ever run on real mates.
internal enum SpecialCheckmate: String, Codable, Sendable, CaseIterable {

    // Ordered for a reader; precedence lives in `precedence` below, so reordering this list cannot
    // change what a game classifies as.
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

    /// The one user-facing rendering (smart-tag picker, Checkmate Type column, Get Info).
    /// Title case by request ("Back Rank"); unlocalized; deliberately not `rawValue.capitalized`,
    /// which renders `backRank` wrong.
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

    /// The checkmate type, or nil for non-mate / ordinary mate. Self-checking (`isCheckmate` guarded).
    internal static func classify(_ state: GameState) -> SpecialCheckmate? {
        guard state.isCheckmate else { return nil }

        let mated = state.activeColor          // the side to move is the mated side
        guard let king = state.position.kingSquare(for: mated) else { return nil }
        let context = Context(position: state.position, king: king, mated: mated)

        return precedence.first { $0.matches(context) }
    }

    /// Precedence, narrowest motif first (D65′): a mate can honestly fit two shapes and the stored
    /// column holds one value, so the order is the decision. Data, not an `if`-chain. A new case
    /// missing from *this list* never classifies, silently — the witness is the completeness pin.
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

    /// One exhaustive switch, so the compiler refuses a case nobody taught to recognise itself.
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

    /// The mated king and the board around it, derived once for every recogniser.
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

    /// A neighbouring square, or nil off-board or across the a/h seam — every file walk goes through
    /// here so the wrap guard cannot be forgotten at one site.
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

    /// Whether `square` holds a mating-side piece of `type`.
    func isEnemy(_ type: PieceType, at square: Square) -> Bool {
        position[square] == Piece(attacker, type)
    }

    /// Every listed offset that lands on the board holds a friendly piece. **Off-board offsets are
    /// walls and do not disqualify** — a cornered king boxed by two pawns is still smothered.
    func areFriendlyOrWalled(_ offsets: [Int]) -> Bool {
        offsets.allSatisfy { offset in
            guard let square = neighbour(offset) else { return true }
            return isFriendly(square)
        }
    }

    /// Strict twin: every offset must be on the board AND friendly — an épaulette needs real
    /// shoulder pieces; the board edge is not a shoulder pad.
    func areFriendlyAndOnBoard(_ offsets: [Int]) -> Bool {
        offsets.allSatisfy { offset in
            guard let square = neighbour(offset) else { return false }
            return isFriendly(square)
        }
    }
}

// MARK: - Attack queries

extension SpecialCheckmate.Context {

    /// Mating-side knight attacks `square` (generalised — four motifs ask about non-king squares).
    func knightAttacks(_ square: Square) -> Bool {
        position.hasPiece(
            Piece(attacker, .knight),
            steppingFrom: square, offsets: Square.knightOffsets, maxFileDistance: 2
        )
    }

    /// Mating-side pawn attacks `square`; offsets run backwards from the target, `isSquareAttacked`'s
    /// own convention.
    func pawnAttacks(_ square: Square) -> Bool {
        position.hasPiece(
            Piece(attacker, .pawn),
            steppingFrom: square,
            offsets: attacker == .white ? [-7, -9] : [7, 9],
            maxFileDistance: 1
        )
    }

    /// Mating-side **bishop** attacks `square` — bishops only: a queen-supported back-rank rook is
    /// an ordinary back-rank mate, and widening to `.queen` would quietly rename half of them.
    func bishopAttacks(_ square: Square) -> Bool {
        Square.bishopDirections.contains {
            position.rayHitsSlider(
                from: square, direction: $0,
                slider1: .bishop, slider2: .bishop,
                attacker: attacker
            )
        }
    }

    /// Mating side defends `square`, king included — correct, not lax: a king-supported queen is the
    /// textbook shape gueridon and dovetail are built on.
    func isDefended(_ square: Square) -> Bool {
        position.isSquareAttacked(square, by: attacker)
    }

    /// Rook/queen bearing on the king along its **rank** — the back-rank check.
    var rankSliderGivesCheck: Bool { sliderGivesCheck(along: [1, -1]) }

    /// Rook/queen bearing along the king's **file** — the frontal check épaulette and Anastasia's need.
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

    /// A mating rook orthogonally adjacent to the king — always check, nothing between; diagonal
    /// adjacency checks nothing, hence only four orthogonals scanned.
    var adjacentCheckingRook: Square? {
        orthogonalNeighbours.first { isEnemy(.rook, at: $0) }
    }

    /// A checking mating **bishop**, found by walking the king's diagonals (a Boden bishop sits far
    /// away). Bishops only — a diagonal queen is a Dovetail, and the two must not blur.
    var checkingBishopExists: Bool {
        Square.bishopDirections.contains {
            position.rayHitsSlider(
                from: king, direction: $0,
                slider1: .bishop, slider2: .bishop,
                attacker: attacker
            )
        }
    }

    /// An adjacent mating queen with the offset that reached it — the offset separates Guéridon
    /// (orthogonal) from Dovetail (diagonal), so it is returned, not recomputed.
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

    /// Knight check, every on-board neighbour friendly (edges are walls). The checker is a knight by
    /// definition, so no overlap with other motifs — free first place in `precedence`.
    var isSmothered: Bool {
        knightAttacks(king) && areFriendlyOrWalled(Square.kingOffsets)
    }

    /// King on its own back rank, rook/queen checking along it, the forward squares walled by its
    /// own pieces — the "trapped behind its own pawns" motif.
    var isBackRank: Bool {
        king.rank == backRank
        && rankSliderGivesCheck
        && areFriendlyOrWalled([forward - 1, forward, forward + 1])
    }

    /// Edge-file king, rook/queen checking down that file, own piece beside it, knight covering the
    /// inner diagonal escapes (classic: Kh7/g7 pawn, Ne7, rook to h-file).
    var isAnastasia: Bool {
        guard king.file == 0 || king.file == 7 else { return false }
        guard fileSliderGivesCheck else { return false }

        let inward = king.file == 0 ? 1 : -1
        guard let beside = neighbour(inward), isFriendly(beside) else { return false }

        // One inner diagonal is off-board for a corner king — a real Anastasia's — so absent squares are
        // skipped, but at least one must exist and every one present must be covered.
        let diagonals = [inward + 8, inward - 8].compactMap(neighbour)
        return !diagonals.isEmpty && diagonals.allSatisfy(knightAttacks)
    }

    /// Corner king, adjacent rook, knight defending that rook (Kh8, Rh7, Nf6). The defended rook is
    /// what separates this from `anastasia`.
    var isArabian: Bool {
        guard (king.file == 0 || king.file == 7) && (king.rank == 0 || king.rank == 7) else {
            return false
        }
        guard let rook = adjacentCheckingRook else { return false }
        return knightAttacks(rook)
    }

    /// Back-rank rook beside the king, defended by a bishop (Morphy's Rd8#/Bg5). Adjacency required —
    /// without it, any back-rank rook mate with a bishop anywhere would take this name.
    var isOpera: Bool {
        guard king.rank == backRank else { return false }
        guard let rook = adjacentCheckingRook, rook.rank == king.rank else { return false }
        return bishopAttacks(rook)
    }

    /// Two bishops on criss-crossing diagonals, king boxed by its own men. The square-colour
    /// argument removes the need to identify which bishop covers which flight.
    var isBoden: Bool {
        guard checkingBishopExists else { return false }
        guard orthogonalNeighbours.contains(where: bishopAttacks) else { return false }
        guard neighbours.contains(where: isFriendly) else { return false }
        return neighbours.allSatisfy { isFriendly($0) || bishopAttacks($0) }
    }

    /// King flanked on both sides by its own pieces, checked frontally down the file. Deliberately
    /// not back-rank-only; flanks must be real pieces, which also avoids colliding with `anastasia`.
    var isEpaulette: Bool {
        areFriendlyAndOnBoard([-1, 1]) && fileSliderGivesCheck
    }

    /// Defended queen **orthogonally** adjacent, own pieces on the two diagonal rear squares.
    /// Dovetail's mirror — the queen's offset is the only difference.
    var isGueridon: Bool {
        guard let (queen, offset) = adjacentCheckingQueen,
              Square.rookDirections.contains(offset),
              isDefended(queen) else { return false }

        // The two diagonals flanking the rear direction: rear -8 → -9/-7, rear -1 → -9/+7.
        let rear = -offset
        let tails = abs(rear) == 8 ? [rear - 1, rear + 1] : [rear - 8, rear + 8]
        return areFriendlyAndOnBoard(tails)
    }

    /// Defended queen **diagonally** adjacent, own pieces on the two orthogonal rear squares (Cozio).
    var isDovetail: Bool {
        guard let (queen, offset) = adjacentCheckingQueen,
              Square.bishopDirections.contains(offset),
              isDefended(queen) else { return false }

        // A diagonal's vertical and horizontal components ARE the flanking orthogonals: -9 → -8/-1.
        let rear = -offset
        let vertical = rear > 0 ? 8 : -8
        return areFriendlyAndOnBoard([vertical, rear - vertical])
    }

    /// Rook beside the king, defended by a knight, itself defended by a pawn — the three-link chain
    /// is the motif. The pawn need not block a flight square.
    var isHook: Bool {
        guard let rook = adjacentCheckingRook else { return false }
        guard let knight = defendingKnight(of: rook) else { return false }
        return pawnAttacks(knight)
    }

    /// The mating knight defending `square` — the hook needs its square to ask what defends *it*.
    private func defendingKnight(of square: Square) -> Square? {
        for offset in Square.knightOffsets {
            let from = square + offset
            guard from.isOnBoard, abs(from.file - square.file) <= 2 else { continue }
            if isEnemy(.knight, at: from) { return from }
        }
        return nil
    }
}
