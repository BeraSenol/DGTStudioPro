//
//  CollectionViewMode.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 28/04/2026.
//

import SwiftUI

internal enum CollectionViewMode: String, CaseIterable, Identifiable {
    case icons
    case list
    case columns
    case gallery
    
    internal var id: String { rawValue }
    internal var displayName: String { rawValue.capitalized }
    
    internal var systemImage: String {
        switch self {
        case .icons:   "square.grid.2x2"
        case .list:    "list.bullet"
        case .columns: "rectangle.split.3x1"
        case .gallery: "squares.below.rectangle"
        }
    }
}

/// The icons grid's geometry, shared by the Library and Players icons views.
///
/// The columns views stopped reading it with the 2 Aug 2026 Finder-column
/// redesign — their card grids (which borrowed `spacing`/`inset`) were
/// replaced by list-plus-detail panes with no grid in them, so the icons
/// grids are the constants' whole audience again.
///
/// Collection-destination parity is an invariant, and it was once held by
/// three private copies of the same two constants plus three *different*
/// insets — `.padding(.horizontal, 16)`, none, and `.padding(16)`. The inset
/// is not decoration: it comes off the width the six flexible columns divide,
/// so an identically-built card rendered ~5pt narrower in one destination
/// than another at the same window width. One copy makes the parity
/// structural — a sibling can no longer drift without editing what every
/// sibling reads.
///
/// The inset is uniform rather than horizontal-only so the first row clears
/// the toolbar divider and the last clears the window edge; horizontal-only
/// left the top row flush, and no inset left cards touching the sidebar and
/// inspector dividers.
///
/// Rejected: a `ViewModifier` over the whole `ScrollView` / `LazyVGrid` pair.
/// The three grids differ in element type and in callbacks, so it would have
/// to be generic over its content anyway, and it would hide the `LazyVGrid`
/// that each view's previews exist to exercise.
internal enum CollectionGridMetrics {
    
    /// Six columns at a 120pt floor: wide enough that a two-line name is the
    /// exception, narrow enough that wrapping shows itself before the window
    /// is unreasonably wide.
    internal static let columnCount = 6
    internal static let minimumColumnWidth: CGFloat = 120
    
    /// Both axes — the gutters read square.
    internal static let spacing: CGFloat = 16
    
    /// Applied to the grid, not the `ScrollView`, so it scrolls with the
    /// content the way a Finder icon view's does.
    internal static let inset: CGFloat = 16
    
    internal static var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: minimumColumnWidth), spacing: spacing),
            count: columnCount
        )
    }
}
