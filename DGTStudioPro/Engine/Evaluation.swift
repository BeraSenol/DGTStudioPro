import Foundation

/// One engine evaluation, normalized to **white's perspective** (the `[%eval]` convention).
///
/// **`Codable` here is a storage format, not a convenience.** `PGN.evaluations` is a `@Model`
/// property, so every analyzed game in the Library holds these encoded (D12′'s arrangement):
/// renaming a case or an associated value stops every stored evaluation from decoding.
enum Evaluation: Equatable, Sendable, Codable {

    // MARK: Cases

    /// Centipawns, signed from white's perspective; 100 ≈ a pawn.
    case centipawns(Int)

    /// Mate in N plies, signed. `mate(0)` = already checkmate, projected as 0.5 to dodge
    /// sign-of-zero.
    case mate(Int)

    // MARK: Static Constants

    /// Dead equal: the sigmoid's fixed point (probability exactly 0.5), its own mirror under
    /// `flipped`. `EvaluationBarReading` folds a nil evaluation to it.
    static let drawn = Evaluation.centipawns(0)

    // MARK: Computed Properties

    /// White's win probability in [0, 1]: **base-e** logistic at k=400, so +100 cp ≈ 56%. Reading
    /// "k=400" as base-10 gives ≈ 64% and is the mistake to expect. Mates clamp to 1/0. Bar,
    /// graph and swing all read this one curve rather than restating it.
    var whiteWinProbability: Double {
        switch self {
        case .centipawns(let cp):
            return 1.0 / (1.0 + exp(-Double(cp) / 400.0))
        case .mate(let n):
            if n == 0 { return 0.5 }
            return n > 0 ? 1.0 : 0.0
        }
    }

    /// Sign flipped - the UCI parser normalizes side-to-move output to white-relative storage.
    var flipped: Evaluation {
        switch self {
        case .centipawns(let cp): return .centipawns(-cp)
        case .mate(let n):        return .mate(-n)
        }
    }
}

// MARK: PGN `[%eval ...]` Tag Format

extension Evaluation {

    /// The widest centipawn magnitude accepted. Rejects only nonsense, but it is what keeps
    /// `Int(_: Double)` below from trapping on a hostile file - that conversion traps on infinity,
    /// NaN and anything past `Int.max`, so the rejection has to happen at the parse boundary.
    private static let centipawnLimit: Double = 1_000_000

    /// Parses the *content* of `[%eval …]` (wrapping syntax already stripped). The importer's door.
    init?(parsingEvalTagContent content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("#") {
            let mateStr = String(trimmed.dropFirst())
            guard let n = Int(mateStr) else { return nil }
            self = .mate(n)
        } else {
            // Tolerate a leading `+` ("+0.50").
            let normalized = trimmed.hasPrefix("+")
            ? String(trimmed.dropFirst())
            : trimmed
            // `Double(_:)` happily accepts "inf", "nan" and overflow - see `centipawnLimit`.
            guard let pawns = Double(normalized), pawns.isFinite else { return nil }
            let cp = (pawns * 100).rounded()
            guard cp >= -Self.centipawnLimit, cp <= Self.centipawnLimit else { return nil }
            self = .centipawns(Int(cp))
        }
    }

    /// Parses a complete `[%eval …]` tag, the exact Lichess/Chess.com shape. **Test-only**: the
    /// importer strips the wrapper itself and calls the initializer above. This and `evalTag` are
    /// each other's round-trip witness, which is the whole reason both exist.
    init?(parsingEvalTag tag: String) {
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

    /// Content in the Lichess convention: centipawns as pawns to two places, mates as `#N`.
    /// **Test-only** - export writes no evaluations.
    var evalTagContent: String {
        switch self {
        case .centipawns(let cp):
            let pawns = Double(cp) / 100.0
            return String(format: "%.2f", pawns)
        case .mate(let n):
            return "#\(n)"
        }
    }

    /// The full tag - the emitting half of the round-trip pair above.
    var evalTag: String {
        "[%eval \(evalTagContent)]"
    }
}
