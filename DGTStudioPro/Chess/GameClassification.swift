/// The derived-truth pair: named opening + checkmate type (trigger revised).
/// Pure and engine-free — classification is a table lookup and a position predicate, not
/// analysis-time work.
struct GameClassification: Sendable, Hashable {

    let opening: ECOOpening?
    /// Matched book-prefix length in plies — non-nil exactly when `opening` is.
    let openingPlies: Int?
    let specialCheckmate: SpecialCheckmate?

    static let unclassified = GameClassification(
        opening: nil, openingPlies: nil, specialCheckmate: nil
    )

    /// Classifies from stored SAN alone; the two halves fail independently, on purpose.
    static func classify(
        moves: [String],
        using classifier: ECOClassifier
    ) -> GameClassification {
        let match = classifier.match(for: moves)
        return GameClassification(
            opening: match?.opening,
            openingPlies: match?.plies,
            specialCheckmate: specialCheckmate(endingIn: moves)
        )
    }

    /// Replays and asks `SpecialCheckmate`, only for a game that *claims* mate — a cost filter, not
    /// correctness (`classify` self-guards on `isCheckmate`). Spelled `contains("#")`, not
    /// `hasSuffix`, matching the validator; `endedInMate` spells it `hasSuffix` and the
    /// divergence is a standing open item.
    private static func specialCheckmate(endingIn moves: [String]) -> SpecialCheckmate? {
        guard moves.last?.contains("#") == true else { return nil }
        guard let final = try? GameState.starting.replay(moves) else { return nil }
        return SpecialCheckmate.classify(final)
    }
}
