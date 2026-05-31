//
//  DGTRuleSet.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 26/05/2026.
//

/// The rule set a game is played under. Stored and shown on the game; FIDE is
/// the only option in v1, and switching rule sets is a late-stage concern.
/// Illegal-move handling follows FIDE Art. 7.5.1 (reinstate the position before
/// the irregularity), which the recovery system (D6) implements as "return to
/// the last legal position."
internal enum DGTRuleSet: String, CaseIterable, Codable, Sendable {
    case fide = "FIDE"
    
    internal var displayName: String { rawValue }
}
