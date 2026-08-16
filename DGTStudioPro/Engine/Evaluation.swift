import Foundation

/// One engine evaluation, normalized to **white's perspective** (the `[%eval]` convention).
enum Evaluation: Equatable, Sendable, Codable {
    
    // MARK: Cases
    
    /// Centipawns, signed from white's perspective; 100 ≈ a pawn.
    case centipawns(Int)
    
    /// Mate in N plies, signed. `mate(0)` = already checkmate, treated as 0.5 by the probability
    /// projection to dodge sign-of-zero.
    case mate(Int)
    
    // MARK: Static Constants
    
    /// Dead equal: the sigmoid's fixed point (probability exactly 0.5), its own mirror under
    /// `flipped`. The bar folds a nil per-ply evaluation to this.
    static let drawn = Evaluation.centipawns(0)
    
    // MARK: Computed Properties
    
    /// White's win probability in [0, 1]: **base-e** logistic at k=400 - +100 cp ≈ 56%, gentler
    /// than the base-10 reading of "k=400" (≈ 64%), which a test literal once assumed and ⌘U
    /// corrected. Mates clamp to 1/0. Every consumer (bar, graph, swing) shares this one curve.
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
    
    /// The widest centipawn magnitude accepted - rejects only nonsense, but finite and inside
    /// `Int`, which keeps `Int(_: Double)` from trapping on a hostile file.
    private static let centipawnLimit: Double = 1_000_000
    
    /// Parses the *content* of `[%eval …]` (wrapping syntax already stripped).
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
            // `Double(_:)` accepts "inf"/"nan"/overflow and `Int(_: Double)` traps on all of them - the
            // rejection belongs at the parse boundary.
            guard let pawns = Double(normalized), pawns.isFinite else { return nil }
            let cp = (pawns * 100).rounded()
            guard cp >= -Self.centipawnLimit, cp <= Self.centipawnLimit else { return nil }
            self = .centipawns(Int(cp))
        }
    }
    
    /// Parses a complete `[%eval …]` tag, the exact Lichess/Chess.com shape. Kept as the pinned
    /// round-trip pair with `evalTag` - export writes no evals.
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
    var evalTagContent: String {
        switch self {
        case .centipawns(let cp):
            let pawns = Double(cp) / 100.0
            return String(format: "%.2f", pawns)
        case .mate(let n):
            return "#\(n)"
        }
    }
    
    /// The full tag. Unused in production (export writes no evaluations) - the round-tripped pair.
    var evalTag: String {
        "[%eval \(evalTagContent)]"
    }
}
