/// Validates a proposed movetext for an edit to an archived game (M-lib.3,
/// D18′). No new legality algorithm — the chess core already is one, so the
/// proposed SAN is replayed ply-by-ply from the standard start position
/// through `parseSAN`/`applying`. The edit is accepted iff every ply is legal
/// *and* the claimed result is consistent with the final position where that
/// result is forced. Accept-whole-or-reject-whole: a rejection names the
/// first offending ply and nothing partially applies.
///
/// Result-consistency rules:
/// - **Checkmate forces the mating side's win.** The position outranks an
///   annotation a human may simply have omitted, so the terminal state decides
///   and a `#` is never taken on trust.
/// - **A trailing `#` must actually mate** — `Qd2#` on a non-mate is a lie the
///   parser would silently swallow, caught here against reality.
/// - **Stalemate forces a draw** — the only other position-forced result.
/// - **`*` is never a finished result** (Decision #3).
///
/// Anything a final position cannot *disprove* — a draw by agreement, a win by
/// resignation from a non-terminal position — is accepted. That is the "where
/// claimable" boundary.
///
/// Accepted movetext is returned **canonicalized** (`san(for:)` per ply):
/// storage stays uniform with app-generated games, and — the load-bearing
/// reason — `GameRecord.endedInMate` reads `moves.last?.hasSuffix("#")`, so a
/// user who omits the `#` on a real mate must still land one in storage or
/// the mate signal silently drops.
internal enum MovetextEdit {
    
    /// A validated, ready-to-store edit. Produced only by `validate` — the
    /// store commits `moves` verbatim, so this type existing *is* the
    /// "persisted movetext never bypasses the replayer" invariant.
    internal struct Accepted: Equatable {
        /// Canonical SAN, one string per ply.
        internal let moves: [String]
        /// The position after the last ply — the terminal state the result
        /// was checked against (handy for an editor previewing the outcome).
        internal let finalState: GameState
    }
    
    /// Why a proposed movetext was refused. Every case is user-facing.
    internal enum Rejection: Error, Equatable {
        /// The ply at `index` (0-based) is illegal in the position it reaches;
        /// `reason` is the parser's verdict (no legal match, ambiguous, …).
        case illegalMove(index: Int, san: String, reason: SANParseError)
        /// The final ply carries `#` but the position is not checkmate.
        case claimsCheckmateButPositionIsNot(san: String)
        /// The final position is checkmate; the result must be the mating
        /// side's win, which `claimed` is not.
        case checkmateResultMismatch(expected: GameResult, claimed: GameResult)
        /// The final position is stalemate; the result must be a draw.
        case stalemateRequiresDraw(claimed: GameResult)
        /// An archived game can't be `*` (Decision #3).
        case resultRequiresDecision
        /// A result token (`1-0`, `0-1`, `1/2-1/2`, `*`) appears *before the
        /// end* of the text — two concatenated games, which would otherwise
        /// validate as one whenever the second game's plies happen to replay
        /// legally (M2 item 3). The editor-door sibling of
        /// `PGNParser.Error.multipleGames`. A *trailing* result token stays
        /// legal: it's dropped as paste convenience, not treated as a claim.
        case splicedGames(token: String)
    }
    
    /// Replays `proposed` from `start`, returning either the canonical,
    /// storable edit or the first reason it was refused.
    ///
    /// The loop mirrors `GameState.replay` rather than calling it: this path
    /// needs the per-ply canonical SAN and the final state together, which
    /// `replay` (the "final state only" convenience) discards — the same
    /// reasoning `replay`'s own doc gives for why history-scrubbing callers
    /// loop themselves.
    internal static func validate(
        _ proposed: [String],
        claimedResult: GameResult,
        from start: GameState = .starting
    ) -> Result<Accepted, Rejection> {
        var state = start
        var canonical: [String] = []
        canonical.reserveCapacity(proposed.count)
        
        for (index, san) in proposed.enumerated() {
            let move: Move
            do {
                move = try state.parseSAN(san)
            } catch {
                // `parseSAN` is `throws(SANParseError)`, so `error` is typed
                // and this arm is exhaustive — the old second `catch` existed
                // only to satisfy untyped `throws` and was documented as
                // unreachable. The compiler now enforces what the comment claimed.
                return .failure(.illegalMove(index: index, san: san, reason: error))
            }
            canonical.append(state.san(for: move))
            state = state.applying(move)
        }
        
        // A trailing `#` must match reality. Checked against `proposed` rather
        // than `canonical` because the canonical `#` is derived from the
        // position — comparing a derived mate marker to itself would always
        // pass and never catch the lie. `parseSAN` dropped the suffix on its
        // way in, so the raw input is the only place the user's claim survives.
        // `contains`, not `hasSuffix`: `tokenize` drops move numbers and a
        // trailing result token but not `!`/`?`, so `Qd2#!` still claims mate
        // and a suffix test would wave it through.
        if let last = proposed.last, last.contains("#"), !state.isCheckmate {
            return .failure(.claimsCheckmateButPositionIsNot(san: last))
        }
        
        // Decision #3 first: `*` is refused regardless of the final position,
        // so checking it after the position-forced block only meant a `*` on a
        // real mate was reported as a checkmate-result mismatch — true, but not
        // the sentence the user needs.
        guard claimedResult != .ongoing else {
            return .failure(.resultRequiresDecision)
        }
        
        // Position-forced results.
        if state.isCheckmate {
            let winner: GameResult = state.activeColor == .white ? .blackWins : .whiteWins
            guard claimedResult == winner else {
                return .failure(.checkmateResultMismatch(expected: winner, claimed: claimedResult))
            }
        } else if state.isStalemate {
            guard claimedResult == .draw else {
                return .failure(.stalemateRequiresDraw(claimed: claimedResult))
            }
        }
        
        return .success(Accepted(moves: canonical, finalState: state))
    }
}

// MARK: Movetext Tokenization

extension MovetextEdit {
    
    /// Splits free-form movetext into SAN tokens for validation: whitespace-
    /// separated, with move numbers (`12.`, `12...`, and glued `1.e4`) dropped,
    /// and a result token (`1-0`, `0-1`, `1/2-1/2`, `*`) dropped **only when it
    /// closes the text** — a pasted game usually ends in one, and the result is
    /// claimed by the archived game, not by the paste. A result token with
    /// tokens *after* it throws `.splicedGames`: it marks a second game glued
    /// on, and silently dropping it was exactly how two games could validate
    /// as one (M2 item 3). SAN only — no comment/variation/NAG handling (that
    /// is the importer's job); a stray `{…}` simply surfaces as an illegal
    /// ply, which is honest feedback.
    ///
    /// Note the asymmetry left in place, deliberately: a trailing token that
    /// *contradicts* the claimed result (text ends `1-0`, game says `0-1`) is
    /// still dropped without comment — the sheet shows the game's result and
    /// validates against it; the paste's trailing token is convenience, never
    /// a second source of truth.
    internal static func tokenize(_ movetext: String) throws(Rejection) -> [String] {
        let tokens = movetext
            .split(whereSeparator: \.isWhitespace)
            .map(strippingMoveNumberPrefix)
            .filter { !$0.isEmpty }
        if let index = tokens.firstIndex(where: { resultTokens.contains($0) }),
           index != tokens.indices.last {
            throw Rejection.splicedGames(token: tokens[index])
        }
        return tokens.filter { !resultTokens.contains($0) }
    }
    
    private static let resultTokens: Set<String> = Set(GameResult.allCases.map(\.rawValue))
    
    /// Drops a leading `<digits><dots>` run — the move number, whether spaced
    /// (`12.`) or glued to the move (`1.e4` → `e4`). Only strips when a dot
    /// follows the digits, so a bare number (not valid SAN anyway) falls
    /// through to validation, and real SAN — never digit-led — is untouched.
    private static func strippingMoveNumberPrefix(_ token: Substring) -> String {
        let afterDigits = token.drop(while: \.isNumber)
        guard afterDigits.count < token.count, afterDigits.first == "." else {
            return String(token)
        }
        return String(afterDigits.drop(while: { $0 == "." }))
    }
}
