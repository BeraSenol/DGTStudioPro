/// Validates a proposed movetext by full replay - the chess core already is the legality
/// algorithm. Accepted iff every ply is legal and the result is consistent where claimable:
/// a trailing `#` must actually mate; checkmate forces the winner; stalemate forces a draw;
/// `*` is never a finished result. Accept whole or reject whole.
enum MovetextEdit {
    
    /// A validated edit. Produced only by `validate` - this type existing *is* the "persisted
    /// movetext never bypasses the replayer" invariant.
    struct Accepted: Equatable {
        /// Canonical SAN, one string per ply.
        let moves: [String]
        /// The position after the last ply - what the result was checked against.
        let finalState: GameState
    }
    
    /// Why a proposed movetext was refused. Every case is user-facing.
    enum Rejection: Error, Equatable {
        /// The ply at `index` is illegal; `reason` is the parser's verdict.
        case illegalMove(index: Int, san: String, reason: SANParseError)
        /// The final ply carries `#` but the position is not checkmate.
        case claimsCheckmateButPositionIsNot(san: String)
        /// The position is checkmate and `claimed` is not the mating side's win.
        case checkmateResultMismatch(expected: GameResult, claimed: GameResult)
        /// The final position is stalemate; the result must be a draw.
        case stalemateRequiresDraw(claimed: GameResult)
        /// An archived game can't be `*`.
        case resultRequiresDecision
        /// A result token *before the end* - two concatenated games (they would validate as one
        /// whenever the second game's plies replay legally). A *trailing* token stays legal: paste
        /// convenience, not a claim.
        case splicedGames(token: String)
    }
    
    /// Replays `proposed` from `start` - canonical storable edit, or the first refusal. Mirrors
    /// `GameState.replay` rather than calling it: this path needs every intermediate state.
    ///
    /// `start` is `.starting` at every call site today; it exists for a game whose draft carries a
    /// non-standard `startFEN`.
    static func validate(
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
                // `throws(SANParseError)` - typed, so this arm is exhaustive; the old second catch was
                // documented unreachable and is now compiler-enforced.
                return .failure(.illegalMove(index: index, san: san, reason: error))
            }
            canonical.append(state.san(for: move))
            state = state.applying(move)
        }
        
        // A trailing `#` must match reality, checked against `proposed` (the canonical `#` is derived
        // from the position - comparing it to itself always passes). `contains`, not `hasSuffix`:
        // `tokenize` keeps `!`/`?`, so `Qd2#!` still claims mate.
        if let last = proposed.last, last.contains("#"), !state.isCheckmate {
            return .failure(.claimsCheckmateButPositionIsNot(san: last))
        }
        
        // The asterisk rule first: a `*` on a real mate must be reported as "*", not as a checkmate-result
        // mismatch - true, but not the sentence the user needs.
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
    
    /// Splits movetext into SAN tokens: move numbers dropped (spaced or glued), a result token
    /// dropped **only when it closes the text** - mid-text ones throw `.splicedGames`. SAN only.
    /// Asymmetry left in place: a trailing token contradicting the claimed result is dropped silently.
    static func tokenize(_ movetext: String) throws(Rejection) -> [String] {
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
    
    /// Drops a leading `<digits><dots>` run. Only when a dot follows the digits - real SAN is never
    /// digit-led, and `1-0` / `1/2-1/2` must survive to be recognised as result tokens.
    private static func strippingMoveNumberPrefix(_ token: Substring) -> String {
        let afterDigits = token.drop(while: \.isNumber)
        guard afterDigits.count < token.count, afterDigits.first == "." else {
            return String(token)
        }
        return String(afterDigits.drop(while: { $0 == "." }))
    }
    
    /// The character range of ply `index`'s SAN inside `movetext` - the token `tokenize` would emit
    /// at that position, minus any move-number prefix - or nil when no such ply exists. Character
    /// offsets, so a display layer can mark the offending move without re-tokenizing.
    ///
    /// Walks by `tokenize`'s own rules - same splitter, same prefix stripper, same result-token
    /// skip - so the two cannot disagree about which token is ply N. The range arithmetic below
    /// leans on the stripper removing only a *leading* run, which leaves the kept text as a suffix
    /// of the raw token; a stripper that also trimmed the tail would misplace every mark.
    static func characterRange(ofPly index: Int, in movetext: String) -> Range<Int>? {
        guard index >= 0 else { return nil }
        var seen = 0
        
        func match(_ token: String, endingAt end: Int) -> Range<Int>? {
            let stripped = strippingMoveNumberPrefix(Substring(token))
            guard !stripped.isEmpty, !resultTokens.contains(stripped) else { return nil }
            defer { seen += 1 }
            guard seen == index else { return nil }
            return (end - stripped.count)..<end
        }
        
        var position = 0
        var token = ""
        for character in movetext {
            if character.isWhitespace {
                if !token.isEmpty {
                    if let range = match(token, endingAt: position) { return range }
                    token = ""
                }
            } else {
                token.append(character)
            }
            position += 1
        }
        if !token.isEmpty, let range = match(token, endingAt: position) { return range }
        return nil
    }
}
