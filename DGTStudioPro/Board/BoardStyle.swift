import SwiftUI

internal enum BoardStyle: String, CaseIterable, Codable, Sendable {
    case leather
    case rosewood
    case walnut
    case wenge
    
    // MARK: Computed Properties
    internal var displayName: String {
        self.rawValue.capitalized
    }
    
    internal var light: Color {
        switch self {
        case .leather:  .leatherLight
        case .rosewood: .rosewoodLight
        case .walnut:   .walnutLight
        case .wenge:    .wengeLight
        }
    }
    
    internal var dark: Color {
        switch self {
        case .leather:  .leatherDark
        case .rosewood: .rosewoodDark
        case .walnut:   .walnutDark
        case .wenge:    .wengeDark
        }
    }
}
