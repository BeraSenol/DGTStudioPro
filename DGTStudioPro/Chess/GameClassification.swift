/// The derived-truth pair a game learns about itself: which named opening it
/// played, and which checkmate type it ended on (D19′, trigger revised by
/// D34′).
///
/// One entry point for both because they are stamped, cleared and backfilled
/// together — `PGNStore.applyMovetextEdit` invalidates both on the same edit,
/// and a caller that could stamp one without the other would eventually
/// stamp one without the other.
///
/// **Pure, and deliberately engine-free.** D19′ recorded classification as
/// analysis-time work, which made an opening name — a table lookup that never
/// needed Stockfish — cost a full depth-18 pass over an already-analysed
/// archive. D34′ splits the two: the analysis pass still stamps, but so does
/// a Library backfill, and neither needs the other.
internal struct GameClassification: Sendable, Hashable {

    internal let opening: ECOOpening?
    internal let specialCheckmate: SpecialCheckmate?

    internal static let unclassified = GameClassification(
        opening: nil, specialCheckmate: nil
    )

    /// Classifies a game from its stored SAN alone.
    ///
    /// The two halves fail independently, on purpose. The opening is pure
    /// string matching, so it survives a game whose movetext the replayer
    /// chokes on — a corrupt import still gets its name. The checkmate type
    /// needs the real final position, so an unreplayable game classifies
    /// `nil` there rather than guessing.
    internal static func classify(
        moves: [String],
        using classifier: ECOClassifier
    ) -> GameClassification {
        GameClassification(
            opening: classifier.opening(for: moves),
            specialCheckmate: specialCheckmate(endingIn: moves)
        )
    }

    /// Replays to the final position and asks `SpecialCheckmate`, but only
    /// for a game that *claims* mate.
    ///
    /// The gate is the standing PGN convention `GameRecord.endedInMate`
    /// already relies on — the last SAN carries `#` — and it earns its keep
    /// on a backfill: without it every game in the Library pays a full
    /// move-generating replay to be told it isn't a mate. `SpecialCheckmate`
    /// self-guards on `isCheckmate` anyway, so the gate is a cost filter, not
    /// a correctness one; a game that claims `#` and isn't mate still
    /// classifies `nil`.
    ///
    /// Spelled `contains("#")`, not `hasSuffix` — and the reason recorded
    /// here until 6 August 2026 was **false**. It read "annotations survive
    /// import, so `Qd2#!` claims mate". They do not: `PGNParser.flushToken`
    /// passes every token through `stripAnnotations`, which strips trailing
    /// `!`/`?`, and that is the *only* `moves.append` in the parser. The other
    /// two writers store `san(for:)` output, which appends `#` or `+` and
    /// nothing else. **No door in this app can store a move with `#` anywhere
    /// but last** — pinned by `annotationsDoNotSurviveImport`.
    ///
    /// The spelling survives its own justification, on a narrower argument:
    /// this is a pure function over a `[String]` it does not own, so
    /// tolerating an annotated final ply costs one character against a future
    /// caller that hasn't canonicalized. `GameRecord.endedInMate` spells the
    /// same question `hasSuffix` because it reads `PGN.moves`, which *is* the
    /// canonical form. Both are right about their own input, and the
    /// "divergence" the open-items list carried for a week has no value either
    /// can disagree on.
    private static func specialCheckmate(endingIn moves: [String]) -> SpecialCheckmate? {
        guard moves.last?.contains("#") == true else { return nil }
        guard let final = try? GameState.starting.replay(moves) else { return nil }
        return SpecialCheckmate.classify(final)
    }
}
