import Foundation

/// The bar's pure mapping: `Evaluation?` in, fraction + tip label out. The fraction is
/// `whiteWinProbability` **verbatim**, so bar and graph can never disagree; nil folds to
/// `.drawn`. Presence is deliberately not this type's job - the wiring gates on `hasScoredPly`.
struct EvaluationBarReading: Equatable, Sendable {
    
    // MARK: Stored Properties
    
    /// White's share of the bar, in `[0, 1]`. 0.5 is dead equal.
    let whiteFraction: Double
    
    /// The tip label (always visible): signed pawns to one decimal, unsigned "0.0" for anything
    /// rounding to zero, mates in the `evalTagContent` spelling. `String(format:)`, not
    /// `.formatted()` - the latter localizes the decimal separator and breaks the pinned grammar.
    let label: String
    
    // MARK: Initializer
    
    /// Optional in - nil folds to `.drawn`, matching the graph's `?? 0.5`.
    init(_ evaluation: Evaluation?) {
        let evaluation = evaluation ?? .drawn
        self.whiteFraction = evaluation.whiteWinProbability
        
        switch evaluation {
        case .centipawns(let cp):
            let pawns = (Double(cp) / 100 * 10).rounded() / 10
            // **The zero case is a guard, not a shortcut.** A small negative - anything from -1 to
            // -4 centipawns - rounds to `-0.0`, and `%+.1f` preserves the sign bit and prints
            // "-0.0". `-0.0 == 0` is true, so this arm catches it and prints the unsigned form.
            self.label = pawns == 0
            ? "0.0"
            : String(format: "%+.1f", pawns)
        case .mate(let n):
            self.label = "#\(n)"
        }
    }
}
