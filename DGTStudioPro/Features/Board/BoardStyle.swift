import SwiftUI

enum BoardStyle: String, CaseIterable, Codable, Sendable {
    case leather
    case rosewood
    case walnut
    case wenge
    
    // MARK: Computed Properties
    var displayName: String {
        self.rawValue.capitalized
    }
    
    var light: Color {
        switch self {
        case .leather:  .leatherLight
        case .rosewood: .rosewoodLight
        case .walnut:   .walnutLight
        case .wenge:    .wengeLight
        }
    }
    
    var dark: Color {
        switch self {
        case .leather:  .leatherDark
        case .rosewood: .rosewoodDark
        case .walnut:   .walnutDark
        case .wenge:    .wengeDark
        }
    }
}
