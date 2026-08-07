import SwiftUI

/// The icons grids' selection grammar — arrow stepping and rubber-band
/// rectangles — extracted from `LibraryIconsView` the day Players' grid
/// became its second host. The gesture and focus plumbing stays per view
/// (different element types, different cards); *this* is the half that
/// must not fork, because two grids answering "where does ↓ land on a
/// partial row" differently is a divergence a user feels and no test
/// smells. One spelling, four hosts, suited once: both galleries joined
/// on 4 Aug 2026 through the one-row degenerate case (`columnCount ==
/// count` — ← / → clamp, ↑ / ↓ hold; pinned by `aFilmstripIsAOneRowGrid`).
internal enum IconGridSelection {

    /// Finder's arrow grammar on a fixed-column grid, as index math so it
    /// needs no frames: left/right step reading order and therefore wrap
    /// across rows; up holds on the top row; down holds on the last row,
    /// and from a card with a hole beneath it (the final partial row's
    /// shadow) lands on the last card rather than dying in the hole.
    internal static func destination(
        from index: Int,
        direction: MoveCommandDirection,
        columnCount: Int,
        count: Int
    ) -> Int {
        switch direction {
        case .left:
            max(index - 1, 0)
        case .right:
            min(index + 1, count - 1)
        case .up:
            index - columnCount >= 0 ? index - columnCount : index
        case .down:
            // Hold anywhere on the last row — the mirror of `.up`'s
            // top-row hold. Without the row guard, the overflow clamp
            // below slid a last-row card *sideways* to the last card
            // (12 → 13 at 6 columns, count 14): a vertical key performing
            // a horizontal move. The clamp is only for cards with a hole
            // beneath them, which is always a row above the last one.
            index / columnCount == (count - 1) / columnCount
            ? index
            : min(index + columnCount, count - 1)
        @unknown default:
            index
        }
    }

    /// A drag's rectangle regardless of sweep direction — normalized so a
    /// leftward or upward drag is the same band as its mirror.
    internal static func selectionRect(from origin: CGPoint, to point: CGPoint) -> CGRect {
        CGRect(
            x: min(origin.x, point.x),
            y: min(origin.y, point.y),
            width: abs(origin.x - point.x),
            height: abs(origin.y - point.y)
        )
    }

    /// The geometry transform's stability rule — one spelling for both grids
    /// (4 Aug 2026, the **fourth** correction on "Geometry action is cycling
    /// between duplicate values", replacing `.integral`).
    ///
    /// `onGeometryChange` compares the transform's output by exact equality
    /// and warns when consecutive layout passes alternate between outputs it
    /// has seen before. The first two corrections killed real feedback
    /// (content anchoring; the box instead of observed state). `.integral`
    /// was the third, meant to absorb sub-point float wobble — and it
    /// *amplified* it instead, because floor/ceil put the decision
    /// boundaries exactly on the integers, which is exactly where macOS
    /// layout rests: a ±0.0002 wobble across 91.0 flips the far edge a
    /// whole point (91 ↔ 92), which is precisely the A/B/A/B the warning
    /// names. Multi-pass ScrollView/LazyVGrid sizing supplies that wobble
    /// freely — six flexible columns divide non-integer widths.
    ///
    /// Rounding to nearest on the **half-point grid** moves the boundaries
    /// to .25/.75, where layout never lands — cells rest on integers at 1×
    /// and halves at 2× — so wobble collapses to one value at every real
    /// anchor. A rubber band is indifferent to half a point either way.
    internal static func stableFrame(_ rect: CGRect) -> CGRect {
        func quantized(_ value: CGFloat) -> CGFloat {
            (value * 2).rounded() / 2
        }
        return CGRect(
            x: quantized(rect.minX),
            y: quantized(rect.minY),
            width: quantized(rect.width),
            height: quantized(rect.height)
        )
    }
}

/// Card-frame storage the geometry actions write and only the drag gesture
/// reads — deliberately a plain reference box, **not** observed state.
/// Nothing in either grid's `body` renders from these frames, so a frame
/// write must never invalidate the view: the first two designs stored a
/// `@State` dictionary, and every report re-entered layout, which is what
/// Console's "Geometry action is cycling between duplicate values" was
/// flagging — the observer was the oscillator. (Re-anchoring the
/// coordinate space was tried first and treated the wrong half; this
/// breaks the loop structurally rather than by guard.) Non-`Sendable` and
/// unannotated on purpose: it lives in a view's `@State` and is touched
/// only from that view's main-actor closures.
internal final class IconGridFrameStore<ID: Hashable> {
    internal var frames: [ID: CGRect] = [:]
    internal init() {}
}

/// The grid's measured container width, on the same terms and for the same
/// reason (7 Aug 2026).
///
/// **This shipped as `@State` first and reproduced the warning on the first
/// launch**, four times over — which is the fifth instance of a lesson this
/// file already carried in writing, one declaration above. The shape is
/// identical: a geometry action wrote observed state, the write invalidated
/// the view, the invalidation re-entered layout, and layout produced another
/// geometry report. Nothing in `body` reads this — the layout reads the
/// `GeometryReader`'s proxy directly, and only `move(_:proxy:)` reads the
/// stored width, from a key-press closure long after layout has settled. So
/// the write must be invisible to the render pass, which is what a box is.
///
/// Kept separate from `IconGridFrameStore` rather than folded in as another
/// property: the frames are per-card and keyed, this is one number for the
/// container, and a store holding both would tempt a future reader into
/// clearing them together.
internal final class IconGridWidthBox {
    internal var width: CGFloat = 0
    internal init() {}

    /// Half-point quantization, the `stableFrame` rule applied to a scalar.
    ///
    /// The box write cannot cycle, but `onGeometryChange` compares its
    /// *transform's* output by exact equality and warns when consecutive
    /// passes alternate between values it has seen. A flexible-column grid
    /// divides non-integer widths freely, so the raw width wobbles sub-point;
    /// rounding to the half-point grid puts the boundaries at .25/.75, where
    /// layout never rests. A column count is indifferent to half a point.
    internal static func quantized(_ width: CGFloat) -> CGFloat {
        (width * 2).rounded() / 2
    }
}
