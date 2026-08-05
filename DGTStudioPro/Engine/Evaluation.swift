import Foundation

/// A single engine evaluation of a chess position.
///
/// All values are normalized to **white's perspective**: positive favors
/// white, negative favors black. This is the PGN `[%eval ...]` convention
/// used by Lichess, Chess.com, and ChessBase, and is the storage format
/// throughout the app. UCI input from the engine arrives in side-to-move
/// perspective and is flipped at the parsing layer when black is to move.
internal enum Evaluation: Equatable, Sendable, Codable {
    
    // MARK: Cases
    
    /// Material-equivalent advantage in centipawns, signed from white's
    /// perspective. `centipawns(0)` is a drawn position; `centipawns(100)`
    /// is roughly "white is a pawn ahead".
    case centipawns(Int)
    
    /// Forced mate in N plies, signed from white's perspective.
    /// `mate(3)` means white mates in 3; `mate(-3)` means black mates
    /// in 3. `mate(0)` indicates the position is already checkmate
    /// (rarely emitted in stored evaluations) and is treated as 0.5
    /// by the probability projection to avoid sign-of-zero ambiguity.
    case mate(Int)
    
    // MARK: Static Constants
    
    /// A dead-equal position: the sigmoid's fixed point, where
    /// `whiteWinProbability` is exactly 0.5, and its own mirror under
    /// `flipped` (`Int` has no negative zero). Named for the vertical
    /// evaluation bar — which, since M3, consumes it: a nil per-ply
    /// evaluation folds to this in `EvaluationBarReading`, so ply 0 reads
    /// neutral without spelling `.centipawns(0)` at the fold site — the
    /// `Position.starting` / `CastlingRights.none` convention.
    internal static let drawn = Evaluation.centipawns(0)
    
    // MARK: Computed Properties
    
    /// Probability that white wins the resulting game, in `[0, 1]`.
    ///
    /// Centipawns project via a sigmoid with k=400, the de-facto-standard
    /// tuning used by Lichess and most analysis interfaces. Mate
    /// evaluations clamp to 1.0 (white mates) or 0.0 (black mates).
    /// This is what `EvaluationGraphView` consumes for its curve display.
    internal var whiteWinProbability: Double {
        switch self {
        case .centipawns(let cp):
            return 1.0 / (1.0 + exp(-Double(cp) / 400.0))
        case .mate(let n):
            if n == 0 { return 0.5 }
            return n > 0 ? 1.0 : 0.0
        }
    }
    
    /// Returns the evaluation with its sign flipped (white ↔ black
    /// perspective). Used by the UCI parser to normalize side-to-move-
    /// relative engine output to white-relative storage.
    internal var flipped: Evaluation {
        switch self {
        case .centipawns(let cp): return .centipawns(-cp)
        case .mate(let n):        return .mate(-n)
        }
    }
}

// MARK: PGN `[%eval ...]` Tag Format

extension Evaluation {
    
    /// The widest centipawn magnitude an annotation may claim. Far past any
    /// real engine output (a queen is ~900), so it rejects only nonsense —
    /// but finite and well inside `Int`, which is what keeps
    /// `Int(_: Double)` from trapping on a hostile file.
    private static let centipawnLimit: Double = 1_000_000
    
    /// Parses the *content* of a `[%eval ...]` PGN comment tag (the value
    /// between the keyword and the closing bracket — the caller is
    /// expected to have stripped the wrapping syntax).
    ///
    /// Accepts the two industry-standard forms:
    /// - **Decimal pawn advantage**, e.g. `"0.23"` → `.centipawns(23)`,
    ///   `"-1.50"` → `.centipawns(-150)`. This is the Lichess /
    ///   Chess.com export convention.
    /// - **Mate notation**, e.g. `"#3"` → `.mate(3)`, `"#-3"` →
    ///   `.mate(-3)`.
    ///
    /// Returns `nil` if the content doesn't match either form.
    internal init?(parsingEvalTagContent content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        if trimmed.hasPrefix("#") {
            let mateStr = String(trimmed.dropFirst())
            guard let n = Int(mateStr) else { return nil }
            self = .mate(n)
        } else {
            // Tolerate a leading `+` (some sources emit "+0.50" instead of "0.50").
            let normalized = trimmed.hasPrefix("+")
            ? String(trimmed.dropFirst())
            : trimmed
            // `Double(_:)` accepts "inf", "nan" and overflowing literals, and
            // `Int(_: Double)` traps on every one of them — so an untrusted
            // `{[%eval inf]}` crashed the import instead of failing the
            // annotation. The rejection belongs here, at the parse boundary,
            // beside the others.
            guard let pawns = Double(normalized), pawns.isFinite else { return nil }
            let cp = (pawns * 100).rounded()
            guard cp >= -Self.centipawnLimit, cp <= Self.centipawnLimit else { return nil }
            self = .centipawns(Int(cp))
        }
    }
    
    /// Parses a complete `[%eval ...]` tag, including its wrapping
    /// brackets and keyword — recognizes the exact Lichess/Chess.com shape
    /// and returns nil otherwise. Whitespace around the inner value
    /// is tolerated; missing space between keyword and value is not.
    ///
    /// No production caller: the parser's scanner strips the wrapper itself
    /// and calls `init?(parsingEvalTagContent:)`. Kept, with `evalTag`, as
    /// the pinned round-trip pair — D24′ writes no evals, so the emitting
    /// half waits for a decision that reverses that.
    internal init?(parsingEvalTag tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        let prefix = "[%eval "
        let suffix = "]"
        guard trimmed.hasPrefix(prefix), trimmed.hasSuffix(suffix) else {
            return nil
        }
        let inner = String(
            trimmed.dropFirst(prefix.count).dropLast(suffix.count)
        )
        self.init(parsingEvalTagContent: inner)
    }
    
    /// Renders the *content* of a `[%eval ...]` tag in the Lichess /
    /// Chess.com convention.
    ///
    /// Centipawns emit as a decimal pawn value to two places —
    /// `.centipawns(23)` → `"0.23"`, `.centipawns(-150)` → `"-1.50"`.
    /// Mate evaluations emit as `#N` / `#-N`. Callers wrap this in
    /// `"[%eval ...]"` for the full comment form via `evalTag`.
    internal var evalTagContent: String {
        switch self {
        case .centipawns(let cp):
            let pawns = Double(cp) / 100.0
            return String(format: "%.2f", pawns)
        case .mate(let n):
            return "#\(n)"
        }
    }
    
    /// Renders the full `[%eval ...]` comment tag, ready to embed
    /// inside `{...}` PGN movetext comments. Unused in production —
    /// `PGNSerializer` writes no evaluations (D24′); this and
    /// `init?(parsingEvalTag:)` exist as the round-tripped pair.
    internal var evalTag: String {
        "[%eval \(evalTagContent)]"
    }
}
