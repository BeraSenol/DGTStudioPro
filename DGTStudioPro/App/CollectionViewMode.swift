//
//  CollectionViewMode.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 28/04/2026.
//

import Foundation

internal enum CollectionViewMode: String, CaseIterable, Identifiable {
    case icons
    case list
    case columns
    case gallery

    internal var id: String { rawValue }
    internal var displayName: String { rawValue.capitalized }

    internal var systemImage: String {
        switch self {
        case .icons:   return "square.grid.2x2"
        case .list:    return "list.bullet"
        case .columns: return "rectangle.split.3x1"
        case .gallery: return "squares.below.rectangle"
        }
    }
}
