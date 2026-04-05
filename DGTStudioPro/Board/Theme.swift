//
//  Theme.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/04/2026.
//

import SwiftUI

// MARK: - Board Style
internal enum BoardStyle: String, CaseIterable, Codable, Sendable {
    case leather
    case rosewood
    case walnut
    case wenge
    
    // MARK: - Computed Properties
    internal var displayName: String {
        self.rawValue.capitalized
    }
    
    internal var light: Color {
        switch self {
        case .leather:  return .leatherLight
        case .rosewood: return .rosewoodLight
        case .walnut:   return .walnutLight
        case .wenge:    return .wengeLight
        }
    }
    
    internal var dark: Color {
        switch self {
        case .leather:  return .leatherDark
        case .rosewood: return .rosewoodDark
        case .walnut:   return .walnutDark
        case .wenge:    return .wengeDark
        }
    }
}

// MARK: - Theme
internal struct Theme: Sendable {
    // MARK: - Stored Properties
    internal let style: BoardStyle
    
    // MARK: - Computed Properties
    internal var light: Color { style.light }
    internal var dark:  Color { style.dark }
}
