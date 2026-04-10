//
//  SquareHighlight.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/04/2026.
//

// MARK: Square Highlight
internal struct SquareHighlight: OptionSet, Sendable {
    
    // MARK: Static Constants
    internal static let lastMove = SquareHighlight(rawValue: 1 << 0)
    internal static let check    = SquareHighlight(rawValue: 1 << 1)
    internal static let selected = SquareHighlight(rawValue: 1 << 2)
    
    // MARK: Stored Properties
    internal let rawValue: UInt8
}
