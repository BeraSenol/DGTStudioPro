import os
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
    
    /// The former enum cases, reborn as editable rule sets.
    ///
    /// One factory fed both the first-run seed and the UI-test seed, so the
    /// tests exercised exactly what ships. The UI seed went with its suite on
    /// 3 Aug 2026, leaving the first-run seed as the only caller — which
    /// makes "one factory" a description of the present rather than a
    /// guarantee about it. Worth keeping as one anyway: a second seeding path
    /// that built its own tags is how the shipped defaults and the tested
    /// defaults come apart.
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
            // M4 (D34′). Note the seed is flag-guarded and fires once ever,
            // so an install that already seeded will not grow this tag —
            // deleting the defaults has to stick, and that rule outranks
            // backfilling a new one. Its real jobs are the fresh install and
            // the UI-test seed; an existing install adds it by hand in the
            // editor, which is the same three fields.
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
            // The assertion is the debug-build witness; the log line is
            // the release breadcrumb. Without it a failed seed on a
            // release build is silent — the flag stays unset (a retry
            // next launch, deliberately), but the sidebar just looks
            // inexplicably empty with nothing in Console to say why.
            AppLog.logger(.smarttags)?
                .error("Default smart-tag seed failed: \(error.localizedDescription, privacy: .public)")
            assertionFailure("Default smart-tag seed failed: \(error)")
        }
    }
}
