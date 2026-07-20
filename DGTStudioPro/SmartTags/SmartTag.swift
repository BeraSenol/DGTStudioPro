//
//  SmartTag.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 04/05/2026.
//

import SwiftData
import SwiftUI

/// A tag's sidebar dot color. A fixed palette rather than arbitrary
/// `Color` because a palette is `Codable`-trivial, theme-stable, and
/// what Finder tags trained everyone to expect.
internal enum TagColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case red, orange, yellow, green, blue, purple, gray
    
    internal var id: String { rawValue }
    
    internal var color: Color {
        switch self {
        case .red:    return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        case .gray:   return .gray
        }
    }
}

/// A user-editable smart tag (M-prs.5, D12′): named, colored, rule-based
/// — the Apple Music smart-playlist shape. Replaces the fixed three-case
/// enum; the old built-ins live on as *seeded defaults* (below), fully
/// editable and deletable like anything the user creates.
///
/// Matching delegates whole to the pure `TagRule.evaluate` — the model
/// stores, the value types decide, so the engine's suite runs
/// nonisolated. "Live updating" from the screenshot has no analogue
/// here on purpose: filtering is computed at render, live by
/// construction.
@Model
internal final class SmartTag: Identifiable {
    
    // MARK: Stored Properties
    
    internal var name: String
    internal var colorName: TagColor
    /// `true` = all rules must match; `false` = any (the editor default,
    /// matching the reference screenshot).
    internal var matchAll: Bool
    /// The `PGN.evaluations` precedent: a Codable value array stored
    /// directly on the model.
    internal var rules: [TagRule]
    internal var createdAt: Date
    
    // MARK: Computed Properties
    
    internal var id: PersistentIdentifier { persistentModelID }
    internal var color: Color { colorName.color }
    
    // MARK: Initializers
    
    internal init(
        name: String,
        colorName: TagColor = .blue,
        matchAll: Bool = false,
        rules: [TagRule] = []
    ) {
        self.name = name
        self.colorName = colorName
        self.matchAll = matchAll
        self.rules = rules
        self.createdAt = .now
    }
    
    // MARK: Matching
    
    internal func matches(_ record: GameRecord) -> Bool {
        TagRule.evaluate(rules, matchAll: matchAll, against: record)
    }
    
    // MARK: Defaults
    
    /// The former enum cases, reborn as editable rule sets. One factory
    /// feeds both the first-run seed and the UI-test seed — a single
    /// source, so the tests exercise exactly what ships.
    internal static func defaultTags() -> [SmartTag] {
        [
            SmartTag(
                name: "Checkmate",
                colorName: .red,
                rules: [TagRule(field: .checkmate, comparison: .isTrue)]
            ),
            SmartTag(
                name: "Timed",
                colorName: .orange,
                rules: [TagRule(field: .timed, comparison: .isTrue)]
            ),
            SmartTag(
                name: "First Round",
                colorName: .blue,
                rules: [TagRule(field: .round, comparison: .equals, number: 1)]
            ),
        ]
    }
    
    /// First normal launch only, flag-guarded (`StorageKeys`): deleting
    /// the defaults must stick — reseeding on every empty launch would
    /// make deletion impossible.
    @MainActor
    internal static func seedDefaultsOnce(into container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: StorageKeys.didSeedDefaultSmartTags) else { return }
        
        let context = ModelContext(container)
        for tag in defaultTags() {
            context.insert(tag)
        }
        do {
            try context.save()
            defaults.set(true, forKey: StorageKeys.didSeedDefaultSmartTags)
        } catch {
            assertionFailure("Default smart-tag seed failed: \(error)")
        }
    }
}
