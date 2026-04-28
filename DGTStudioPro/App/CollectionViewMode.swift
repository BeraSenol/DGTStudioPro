//
//  CollectionViewMode.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 28/04/2026.
//

internal enum CollectionViewMode: String, CaseIterable, Identifiable {
    case icons
    case list
    case columns
    case gallery
    
    internal var id: String { rawValue }
    
    internal var systemImage: String {
        switch self {
        case .icons:   return "square.grid.2x2"
        case .list:    return "list.bullet"
        case .columns: return "rectangle.split.3x1"
        case .gallery: return "squares.below.rectangle"
        }
    }
    
    internal var displayName: String {
        switch self {
        case .icons:   return "Icons"
        case .list:    return "List"
        case .columns: return "Columns"
        case .gallery: return "Gallery"
        }
    }
}
