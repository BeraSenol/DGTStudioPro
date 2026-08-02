//
//  IconGridSelection.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 02/08/2026.
//

import SwiftUI

/// The icons grids' selection grammar — arrow stepping and rubber-band
/// rectangles — extracted from `LibraryIconsView` the day Players' grid
/// became its second host. The gesture and focus plumbing stays per view
/// (different element types, different cards); *this* is the half that
/// must not fork, because two grids answering "where does ↓ land on a
/// partial row" differently is a divergence a user feels and no test
/// smells. One spelling, two callers, suited once.
internal enum IconGridSelection {

    /// Finder's arrow grammar on a fixed-column grid, as index math so it
    /// needs no frames: left/right step reading order and therefore wrap
    /// across rows; up holds on the top row; down past the bottom lands on
    /// the last card rather than dying in a hole of the final partial row.
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
            min(index + columnCount, count - 1)
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
