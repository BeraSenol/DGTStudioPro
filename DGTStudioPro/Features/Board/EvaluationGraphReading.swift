import Foundation

/// The graph's one ply↔x mapping — D46′ gave the curve a second consumer pointing the other way
/// (the view places points, the window hit-tests), and open-coded that is one relationship
/// stated twice. Not a general chart abstraction.
struct EvaluationGraphGeometry: Equatable, Sendable {

    // MARK: Stored Properties
    let width: CGFloat
    let plyCount: Int

    // MARK: Initializers
    init(width: CGFloat, plyCount: Int) {
        self.width = width
        self.plyCount = plyCount
    }

    // MARK: Computed Properties

    /// Distance between adjacent plies, or nil — two plies is the minimum that defines a step,
    /// stated once instead of twice.
    var step: CGFloat? {
        guard plyCount >= 2, width > 0 else { return nil }
        return width / CGFloat(plyCount - 1)
    }

    // MARK: Internal Methods

    /// Offset **from the drawing rect's leading edge** — an absolute x would bake one caller's rect
    /// origin into a type the other uses differently.
    func x(forPly ply: Int) -> CGFloat? {
        guard let step, ply >= 0, ply < plyCount else { return nil }
        return CGFloat(ply) * step
    }

    /// The nearest ply, clamped to the ends — a pointer past the edge still means the nearest end;
    /// an empty curve is the only genuine "no answer".
    func ply(nearestTo x: CGFloat) -> Int? {
        guard let step else { return nil }
        let index = Int((x / step).rounded())
        return min(max(index, 0), plyCount - 1)
    }
}

/// One ply's read-out: the move and the engine's verdict. The evaluation label is
/// `EvaluationBarReading`'s verbatim (asserted against the type, not a literal); `move` is a
/// display form — the one surface that must name a single black ply on its own.
struct EvaluationGraphReading: Equatable, Sendable {

    // MARK: Stored Properties
    let move: String
    let evaluation: String

    // MARK: Initializers

    /// Fails when `ply` names no move; a move without an evaluation folds to the bar's nil rule —
    /// the move happened either way.
    init?(ply: Int, moves: [String], evaluations: [Evaluation?]) {
        guard ply >= 0, ply < moves.count else { return nil }

        let number = ply / 2 + 1
        let isWhite = ply.isMultiple(of: 2)
        self.move = isWhite
        ? "\(number). \(moves[ply])"
        : "\(number)… \(moves[ply])"

        let evaluation = ply < evaluations.count ? evaluations[ply] : nil
        self.evaluation = EvaluationBarReading(evaluation).label
    }
}
