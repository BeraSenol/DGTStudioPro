import Foundation

/// The vertical evaluation bar's pure mapping (M3, D33′): one `Evaluation?`
/// in, a bar fraction and a tip label out. A value type with a nonisolated
/// suite, in the `GameHeadline` / `RecoveryGuidance` mould — the view stays
/// dumb and the grammar (what nil means, how mates read, when a sign
/// appears) is the part worth pinning.
///
/// `whiteFraction` is `Evaluation.whiteWinProbability` **verbatim** — the
/// same projection the inspector graph plots — so the bar and the graph can
/// never disagree about a position (the M3 gate sentence, made structural
/// rather than approximate). Mates therefore clamp exactly like the graph:
/// full bar for a white mate, empty for a black one.
///
/// A nil evaluation folds to `Evaluation.drawn` — the neutral midpoint that
/// constant was named for. Two callers produce nil: ply 0 (the one position
/// no move scored) and an unanalysed ply inside an analysed game; the graph
/// renders both at 0.5 (`?? 0.5` at its call site), so the bar does too.
/// *Game-level* absence — an unanalysed game shows no bar at all — is
/// deliberately not this type's job: presence is the wiring's one-line
/// guard on `pgn.hasScoredPly`, because "absence, not a 50/50 lie" is about
/// whether the bar exists, not what it reads.
///
/// That guard read `pgn.evaluations.isEmpty` until D67′ (7 Aug 2026),
/// described here as "the `hasAnalysis` projection's exact truth" — which it
/// was, and both were asking the wrong question. A game whose pass scored
/// nothing carries a full-length all-nil array, so the bar existed and showed
/// exactly the 50/50 lie this paragraph names. `hasAnalysis` followed the
/// same hour (D68′), so the sentence is true again and now says something
/// worth saying: bar presence and the "Analyzed" tag rule are one predicate.
///
/// The reading is **white-relative and perspective-free**: `whiteFraction`
/// and the label's sign always describe white, whatever the board's
/// orientation. Flipping bottom-tracks-near-player (D33′) is one boolean of
/// geometry in `EvaluationBarView` — a rendering concern, not a semantic
/// one, same split as `BoardView.perspective`.
internal struct EvaluationBarReading: Equatable, Sendable {

    // MARK: Stored Properties

    /// White's share of the bar, in `[0, 1]`. 0.5 is dead equal.
    internal let whiteFraction: Double

    /// The numeric readout at the bar's tip (D33′ chose always-visible):
    /// centipawns as signed pawns to one decimal — `"+1.5"`, `"-0.3"` —
    /// with `"0.0"` unsigned for anything that *rounds* to zero (a signed
    /// zero would claim a direction the number no longer shows); mates in
    /// the `evalTagContent` spelling — `"#3"`, `"#-3"`, and the rare
    /// stored `"#0"` (already checkmate; 0.5 by `whiteWinProbability`'s
    /// documented sign-of-zero rule).
    internal let label: String

    // MARK: Initializer

    /// Maps an optional evaluation to its reading. See the type doc for
    /// the nil rule (folds to `.drawn`, matching the graph's `?? 0.5`).
    internal init(_ evaluation: Evaluation?) {
        let evaluation = evaluation ?? .drawn
        self.whiteFraction = evaluation.whiteWinProbability

        switch evaluation {
        case .centipawns(let cp):
            let pawns = (Double(cp) / 100 * 10).rounded() / 10
            self.label = pawns == 0
            ? "0.0"
            : String(format: "%+.1f", pawns)
        case .mate(let n):
            self.label = "#\(n)"
        }
    }
}
