import Foundation
import Observation
import os

/// Which inspector section a header names — the one purpose needing a name: remembering the
/// collapse. **Identity is what a section shows, not which inspector shows it** (fold Opening
/// on the Board, it folds in the Library). Titles cannot supply it: two sections called "Game",
/// neither the game — hence an enum with hand-written raw values.
enum InspectorSection: String, CaseIterable, Sendable {
    case roster         = "roster"
    case opening        = "opening"
    case evaluation     = "evaluation"
    case moves          = "moves"
    case pgn            = "pgn"
    case lifecycle      = "lifecycle"
    case playerProfile  = "playerProfile"
    case recentGames    = "recentGames"
    // `rankingProfile` retired — one grid, one name. A stored collapse under the old raw
    // value drops on read and evicts on next write, the designed retirement path.
    case ratingTrend    = "ratingTrend"
}

/// Which sections are collapsed, persisted under one key. An owning type, not
/// `@AppStorage` — one question in two places would be the twin-read-site pattern
/// (`SleepInhibitor` is the precedent, down to injectable defaults). **The stored set is the
/// collapsed sections**, so "default open" is the representation, not a `?? true`.
@MainActor
@Observable
final class InspectorSectionCollapse {

    // MARK: Type Properties
    @ObservationIgnored
    private static let logger = AppLog.logger(.inspector)

    // MARK: Stored Properties

    /// Observed, so a header toggle re-renders on the same turn; persisted on write.
    private(set) var collapsed: Set<InspectorSection> {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: Initializers

    /// Injectable for the suite and for `preview`. (The third reason — the UI seed's wiped suite —
    /// retired with the suite; `.defaultAppStorage` never reached a hand-constructed instance anyway.)
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.collapsed = Self.read(from: defaults)
    }

    // MARK: Internal Methods

    func isCollapsed(_ section: InspectorSection) -> Bool {
        collapsed.contains(section)
    }

    func toggle(_ section: InspectorSection) {
        if collapsed.contains(section) {
            collapsed.remove(section)
        } else {
            collapsed.insert(section)
        }
    }

    // MARK: Private Methods

    private static func read(from defaults: UserDefaults) -> Set<InspectorSection> {
        let stored = defaults.stringArray(
            forKey: StorageKeys.collapsedInspectorSections
        ) ?? []
        let sections = stored.compactMap(InspectorSection.init(rawValue:))
        if sections.count != stored.count {
            // Not a defect — the retired-section path doing its job. Logged because a *typo* looks
            // identical from the store.
            Self.logger?.info(
                "Ignored \(stored.count - sections.count, privacy: .public) unknown collapsed-section key(s)"
            )
        }
        return Set(sections)
    }

    /// Sorted: a `Set`'s iteration order is unstable, and an unsorted write rewrites the same state
    /// in a different order every time — noise in a defaults dump.
    private func persist() {
        defaults.set(
            collapsed.map(\.rawValue).sorted(),
            forKey: StorageKeys.collapsedInspectorSections
        )
    }
}

// MARK: Previews

extension InspectorSectionCollapse {

    /// The instance every inspector preview injects — a non-optional `@Environment` traps when
    /// missing. Computed, not stored, so each canvas starts clean; the wipe is what makes that true.
    static var preview: InspectorSectionCollapse {
        let name = "preview"
        // `!` over `?? .standard`: the fallback's failure mode is worse than the crash — a canvas
        // silently editing the developer's defaults. A crash points at itself; a leak points at nothing.
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return InspectorSectionCollapse(defaults: defaults)
    }
}
