import SwiftUI

/// The icons grids' selection grammar - arrow stepping and band rectangles - extracted when
/// Players' grid became the second host: this is the half that must not fork. A filmstrip is a
/// one-row grid (`columnCount == count`); pinned.
enum IconGridSelection {

    /// Finder's arrow grammar as index math (no frames): left/right wrap in reading order; up holds
    /// on the top row; down from a card with a hole beneath it lands on the last card.
    static func destination(
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
            // Hold anywhere on the last row - without the row guard, the overflow clamp slid a last-row
            // card *sideways* (a vertical key performing a horizontal move).
            index / columnCount == (count - 1) / columnCount
            ? index
            : min(index + columnCount, count - 1)
        @unknown default:
            index
        }
    }

    /// Finder's rule for what a card's verb acts on: inside a multi-selection, the whole
    /// selection; on anything else, just that card. The list modes get this free from
    /// `.contextMenu(forSelectionType:)` and `primaryAction`; the grids have to spell it, and
    /// spelling it *once* is the point - it belonged to Open alone until 17 Aug 2026, and the
    /// other three verbs quietly acted on one game whatever was selected ("select all, delete
    /// all, it deletes one").
    ///
    /// Ordered off `items`, never off the set: that is tab and processing order, and a `Set`'s
    /// order would number an export's filenames arbitrarily.
    static func subjects<Item: Identifiable>(
        for item: Item,
        in items: [Item],
        selection: Set<Item.ID>
    ) -> [Item] {
        if selection.count > 1, selection.contains(item.id) {
            return items.filter { selection.contains($0.id) }
        }
        return [item]
    }

    /// A drag's rectangle regardless of sweep direction - normalized.
    static func selectionRect(from origin: CGPoint, to point: CGPoint) -> CGRect {
        CGRect(
            x: min(origin.x, point.x),
            y: min(origin.y, point.y),
            width: abs(origin.x - point.x),
            height: abs(origin.y - point.y)
        )
    }

    /// The geometry-transform stability rule, one spelling for both grids - the fourth "cycling
    /// between duplicate values" correction: `.integral` put flip boundaries exactly on the
    /// integers layout rests on, *amplifying* sub-point wobble. Quantize to the half-point grid
    /// (.25/.75), where layout never lands. (The fifth correction gates the observation on the sweep.)
    static func stableFrame(_ rect: CGRect) -> CGRect {
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

/// Card-frame storage the geometry actions write and only the drag reads - a plain reference
/// box, NOT observed state: nothing renders from these frames, so a write must never invalidate
/// the view.
final class IconGridFrameStore<ID: Hashable> {
    var frames: [ID: CGRect] = [:]
    init() {}
}
