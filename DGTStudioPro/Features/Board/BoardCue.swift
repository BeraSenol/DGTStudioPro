/// What the board sounds like. Pure, nonisolated, `GameState`-typed where it needs to be - the
/// classification is the part worth pinning, and it is a value question with no I/O in it (the
/// shape, applied to a presentation concern rather than a fold).
///
/// **Two families, and the split is the reason this type reads oddly at first.** Six cues describe
/// a move that landed and are reachable from `cue(for:landing:)`; three describe something that
/// happened to the *session* - a rejected position, a game beginning, a game ending - and are fired
/// by their own call sites. They share one enum because they share one sample set, one player
/// cache and one filename convention, and splitting them would buy a type distinction at the cost
/// of duplicating all three. `family` keeps the distinction available without paying for it.
///
/// **One cue per move, most specific wins.** A capture that gives check plays `check`, not both:
/// two samples fired at one instant is mush, and the more informative fact is the one worth
/// hearing. Stated here because "capture+check plays capture" is the equally defensible rule and
/// a future reader will wonder which was chosen.
enum BoardCue: String, CaseIterable, Sendable {

    // MARK: Move family - what a landed move sounds like

    case move
    case capture
    case castle
    case promote
    case check
    case checkmate

    // MARK: Event family - what happened to the session

    /// The pieces on the board stopped agreeing with the position. Fired on desync *entry*, once,
    /// not per scan.
    ///
    /// The two hyphenated raw values are explicit rather than taken from the case names, which
    /// would put a capital in a filename. Each raw value **is** a filename stem: `game-start` is
    /// `game-start.wav` in the bundle, and nothing parses these names apart.
    case illegal
    case gameStart = "game-start"
    case gameEnd = "game-end"

    // MARK: Family

    /// Which half of the enum a cue belongs to. Exists so the invariant below is testable rather
    /// than merely documented: `cue(for:landing:)` must never return an event.
    enum Family: Sendable {
        case move
        case event
    }

    var family: Family {
        switch self {
        case .move, .capture, .castle, .promote, .check, .checkmate: .move
        case .illegal, .gameStart, .gameEnd: .event
        }
    }

    // MARK: Samples

    /// The bundled `.wav` files this cue plays, **layered** - every entry fires at once.
    ///
    /// A list rather than a single name, because two cues have no recording of their own and are
    /// defined in terms of the ones that do:
    ///
    /// - `checkmate` is the move landing *and* the game ending, which is what a mate is. Composing
    ///   it here rather than pre-mixing a `checkmate.wav` means replacing either ingredient
    ///   re-voices the mate for free, and there is no derived file to go stale behind your back.
    /// - `promote` borrows the move sound. A promotion is still a piece landing; it earns its own
    ///   *toggle* because you might want to silence it, not its own sample.
    ///
    /// Every name is spelled off another case's `rawValue` rather than as a literal, so renaming a
    /// cue moves its filename **and** every reference to it in one edit. There is no `default:`
    /// arm on purpose: a cue added without a sample should fail to compile here, not fail to make
    /// a sound at the board.
    var resources: [String] {
        switch self {
        case .move:      [Self.move.rawValue]
        case .capture:   [Self.capture.rawValue]
        case .castle:    [Self.castle.rawValue]
        case .promote:   [Self.move.rawValue]
        case .check:     [Self.check.rawValue]
        case .checkmate: [Self.move.rawValue, Self.gameEnd.rawValue]
        case .illegal:   [Self.illegal.rawValue]
        case .gameStart: [Self.gameStart.rawValue]
        case .gameEnd:   [Self.gameEnd.rawValue]
        }
    }

    // MARK: Classification

    /// The cue `move` earns, given the position it lands in. `landing` is the state *after* the
    /// move, so `isInCheck` is asked of the side receiving it - which is what "check" means.
    ///
    /// Ordering is deliberate: `isInCheck` is one attack scan, `legalMoves()` a full generation,
    /// so the expensive question runs only where `checkmate` is possible (`GameState+SAN`'s own
    /// optimisation - `isCheckmate` would pay the scan twice).
    ///
    /// Below the check tests the order is **promote → capture → castle → move**, most informative
    /// first. Promotion outranks capture because a promoting capture is a promotion first: the new
    /// queen is the fact you want to hear, and captures are common where promotions are not.
    /// Castling cannot be a capture, so it never actually competes with one - it sits above `move`
    /// alone, and is listed here rather than folded in because a rook and king landing together is
    /// audibly two pieces, and `castle` is the only cue that says so.
    ///
    /// Stalemate deliberately has no cue and falls through to `move`/`capture`: the position is
    /// drawn, the move was ordinary, no sample. The drawn *game* is `gameEnd`'s business.
    static func cue(for move: Move, landing: GameState) -> BoardCue {
        if landing.isInCheck {
            return landing.legalMoves().isEmpty ? .checkmate : .check
        }
        if move.promotionType != nil { return .promote }
        // En passant included: movegen stamps `capturedPieceType: .pawn` on it, so the bit test
        // covers the one capture whose destination square was empty.
        if move.isCapture { return .capture }
        if move.isCastling { return .castle }
        return .move
    }
}
