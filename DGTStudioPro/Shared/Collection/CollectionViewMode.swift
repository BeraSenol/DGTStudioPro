import SwiftUI

enum CollectionViewMode: String, CaseIterable, Identifiable {
    case icons
    case list
    case columns
    case gallery
    
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    
    var systemImage: String {
        switch self {
        case .icons:   "square.grid.2x2"
        case .list:    "list.bullet"
        case .columns: "rectangle.split.3x1"
        case .gallery: "squares.below.rectangle"
        }
    }

    /// Whether the mode renders its own detail pane (only `.columns`), making the inspector a
    /// second copy of the same facts — the destination forces the inspector shut there.
    var ownsDetailPane: Bool {
        self == .columns
    }
}

/// The icons grids' geometry, shared by both destinations. The inset is uniform so the first
/// row clears the toolbar divider and the last the window edge. (The columns views stopped
/// reading it with the Finder-column redesign; the icon-size default moved to
/// `CollectionViewOptions` — `spacing`/`inset` remain the constants here.)
