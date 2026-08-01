//
//  EvaluationGraphReading.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/08/2026.
//

import Foundation

/// The evaluation graph's one mapping between a ply and a horizontal position.
///
/// It exists because D46′ gave the curve a **second** consumer of that
/// arithmetic. `EvaluationGraphView` has always converted ply → x to place its
/// points; the magnifier window converts x → ply to answer "what is under the
/// pointer". Left open-coded, those are two statements of one relationship in
/// two files, and they agree only while both are edited together — the twin
/// read site D25′ names, in its geometric form. The bar's width taught this
/// lesson once already at a cost of 2 pt of bleed for a month.
///
/// Deliberately *not* a general chart abstraction: it knows one curve's
/// spacing rule and nothing about drawing. `EvaluationBarReading` is the
/// sibling shape — a pure value with a nonisolated suite, so the grammar is
/// pinned and the view stays dumb.
internal struct EvaluationGraphGeometry: Equatable, Sendable {

    // MARK: Stored Properties
    internal let width: CGFloat
    internal let plyCount: Int

    // MARK: Initializers
    internal init(width: CGFloat, plyCount: Int) {
        self.width = width
        self.plyCount = plyCount
    }

    // MARK: Computed Properties

    /// Distance between adjacent plies, or nil when there is no distance to
    /// speak of. Two plies is the minimum that defines a step, which is the
    /// same threshold `EvaluationGraphView` already guards its drawing on —
    /// stated once here instead of twice.
    internal var step: CGFloat? {
        guard plyCount >= 2, width > 0 else { return nil }
        return width / CGFloat(plyCount - 1)
    }

    // MARK: Internal Methods

    /// The ply's offset **from the drawing rect's leading edge**, not an
    /// absolute coordinate — the caller adds its own `minX`. Stated because
    /// returning an absolute x would silently bake one caller's rect origin
    /// into a type the other caller uses with a different one.
    internal func x(forPly ply: Int) -> CGFloat? {
        guard let step, ply >= 0, ply < plyCount else { return nil }
        return CGFloat(ply) * step
    }

    /// The ply nearest a pointer position, clamped to the curve's ends.
    ///
    /// Clamped rather than failable outside the range, deliberately: a pointer
    /// one pixel past the last point is still asking about the last ply, and a
    /// read-out that blanks at the very edge of the graph reads as a bug in the
    /// read-out. Nil means the curve has no plies to point at, which is the
    /// only genuine "no answer".
    internal func ply(nearestTo x: CGFloat) -> Int? {
        guard let step else { return nil }
        let index = Int((x / step).rounded())
        return min(max(index, 0), plyCount - 1)
    }
}

/// What the magnifier window says about one ply: the move that produced it and
/// what the engine thought of the result.
///
/// `evaluation` is `EvaluationBarReading`'s label **verbatim** rather than a
/// second formatter, for the reason D33′ made that grammar a pinned type in
/// the first place: signed pawns to one decimal, unsigned `0.0` for anything
/// that rounds to zero, mates in the `evalTagContent` spelling. Two surfaces
/// describing one number in two ways is a defect the reader has to notice,
/// and they would only ever see it by holding the bar and the window open at
/// once.
///
/// `move` is a **display** form — "12. Nf3", "12… Nf6" — and deliberately not
/// the file form. `PGNSerializer` owns what a move number looks like on disk
/// (D24′, byte-pinned), and this is the one place in the app that needs to
/// name a single black ply on its own, which the serializer's full-move lines
/// never do.
internal struct EvaluationGraphReading: Equatable, Sendable {

    // MARK: Stored Properties
    internal let move: String
    internal let evaluation: String

    // MARK: Initializers

    /// Fails when `ply` names no move. `evaluations` is parallel to `moves` by
    /// `PGN`'s stated invariant — same length or empty — so a ply inside
    /// `moves` may still carry no evaluation, and that folds to the bar's nil
    /// rule rather than to an absent reading: the move happened either way.
    internal init?(ply: Int, moves: [String], evaluations: [Evaluation?]) {
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
