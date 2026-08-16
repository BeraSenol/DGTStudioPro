import os
import SwiftData
import SwiftUI

/// A fixed palette rather than arbitrary `Color`: Codable-trivial, theme-stable, Finder-shaped.
enum TagColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case red, orange, yellow, green, blue, purple, gray
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .red:    .red
        case .orange: .orange
        case .yellow: .yellow
        case .green:  .green
        case .blue:   .blue
        case .purple: .purple
        case .gray:   .gray
        }
    }
}

/// A user-editable smart tag - the Apple Music smart-playlist shape; the old built-ins
/// live on as seeded, fully editable defaults.
@Model
final class SmartTag: Identifiable {
    
    // MARK: Stored Properties
    
    var name: String
    var colorName: TagColor
    /// `true` = all rules must match; `false` = any (the editor default).
    var matchAll: Bool
    /// The `PGN.evaluations` precedent: a Codable value array on the model.
    var rules: [TagRule]
    var createdAt: Date
    /// Sidebar position (16 Aug 2026, drag-to-reorder). Pre-schema rows migrate in at 0 and the
    /// sidebar's `createdAt` tiebreak reproduces exactly the order they already stood in; the
    /// first drag rewrites the run 0..n and owns the order from then on.
    var sortIndex: Int = 0
    
    // MARK: Computed Properties
    
    var id: PersistentIdentifier { persistentModelID }
    var color: Color { colorName.color }
    
    // MARK: Initializers
    
    init(
        name: String,
        colorName: TagColor = .blue,
        matchAll: Bool = false,
        rules: [TagRule] = [],
        sortIndex: Int = 0
    ) {
        self.name = name
        self.colorName = colorName
        self.matchAll = matchAll
        self.rules = rules
        self.createdAt = .now
        self.sortIndex = sortIndex
    }
    
    // MARK: Matching
    
    func matches(_ record: GameRecord) -> Bool {
        TagRule.evaluate(rules, matchAll: matchAll, against: record)
    }
    
    // MARK: Defaults
    
    /// The former enum cases as editable rule sets - the one factory behind the first-run seed.
    static func defaultTags() -> [SmartTag] {
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
            // The seed fires once ever (flag-guarded), so an already-seeded install will not grow this tag
            // - deleting defaults must stick, and that rule outranks completeness.
            SmartTag(
                name: "Smothered Mates",
                colorName: .purple,
                rules: [
                    TagRule(
                        field: .checkmateType,
                        comparison: .equals,
                        specialCheckmate: .smothered
                    )
                ]
            ),
        ]
    }
    
    /// First normal launch only, flag-guarded: reseeding on every empty launch would make deletion
    /// impossible.
    @MainActor
    static func seedDefaultsOnce(into container: ModelContainer) {
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
            // The assertion is the debug witness; the log line the release breadcrumb - a silent failed
            // seed leaves the sidebar inexplicably empty.
            AppLog.logger(.smarttags)?
                .error("Default smart-tag seed failed: \(error.localizedDescription, privacy: .public)")
            assertionFailure("Default smart-tag seed failed: \(error)")
        }
    }
}
