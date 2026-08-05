//
//  InspectorSectionCollapse.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/08/2026.
//

import Foundation
import Observation
import os

/// Which inspector section a header names — needed for the one purpose that
/// requires a section to have a name at all: remembering that it is collapsed.
///
/// **Identity is what the section shows, not which inspector shows it.**
/// Collapsing Opening on the Board also collapses it in the Library, because
/// "I don't want to look at openings right now" is a statement about openings.
/// A per-inspector split would let the same section answer differently
/// depending on how the reader arrived at the same game, which is a
/// distinction the reader never drew.
///
/// **Titles cannot supply the identity**, which is the reason this is an enum
/// and not a string derived from the header. The live inspector's "Game"
/// section holds Resign / Agree Draw / Discard; the Board and Library
/// inspectors' roster section is titled with the game's *name*. Two sections
/// called Game, and the one that is actually the game is not either of them.
///
/// Where two inspectors show genuinely different content under one idea, they
/// get separate cases — the rule that split `playerProfile` from
/// `rankingProfile` when the two grids shared nothing but the name at the
/// top. D48′ merged the grids and retired the second case (see the enum
/// body); the rule outlives its founding example, and the retirement path it
/// exercised is the one this type designed for.
///
/// Raw values are spelled out rather than left to synthesis because they are
/// the **stored** form. Synthesised raw values follow the case names, so a
/// rename that reads as a refactor would silently un-collapse that section for
/// the user; spelled out, the store is something you have to mean to change.
internal enum InspectorSection: String, CaseIterable, Sendable {
    case roster         = "roster"
    case opening        = "opening"
    case evaluation     = "evaluation"
    case moves          = "moves"
    case pgn            = "pgn"
    case lifecycle      = "lifecycle"
    case playerProfile  = "playerProfile"
    case recentGames    = "recentGames"
    // `rankingProfile` retired by D48′ — the merged Players profile is one
    // grid under `.playerProfile`, so two cases would be two names for one
    // section. A stored collapse under the old raw value drops on read and
    // evicts on the next write, the retirement path this type designed for.
    case ratingTrend    = "ratingTrend"
}

/// M8 (D45′) — which inspector sections the user has collapsed, persisted
/// across launches under a single key.
///
/// **An owning type rather than an `@AppStorage` pair**, for D25′'s reason
/// stated as a rule in `StorageKeys`: the header draws the chevron and the
/// host decides whether to render its body, so an `@AppStorage` design would
/// put the same question in two places and rely on them agreeing. They would
/// have agreed, too — right up until one of them didn't. `SleepInhibitor` is
/// the precedent this follows exactly, down to the injectable defaults.
///
/// **The stored set is the collapsed sections, not the expanded ones.** That
/// is what makes "sections default open" free: an absent key and an empty set
/// are the same state, so the default is a property of the representation
/// rather than a `?? true` anybody has to remember. Compare the three
/// preferences in `StorageKeys` that do state a default, each with a twin
/// read site warning attached.
///
/// **An unknown raw value is not a section.** A retired case's entry is
/// dropped on read and written out of existence by the next toggle, so a
/// section can be removed from the app without leaving anything behind and
/// without a migration. The cost, recorded rather than discovered: if a
/// retired section ever comes back, it comes back expanded.
@MainActor
@Observable
internal final class InspectorSectionCollapse {

    // MARK: Type Properties
    @ObservationIgnored
    private static let logger = AppLog.logger(.inspector)

    // MARK: Stored Properties

    /// The collapsed sections. Observed, so a toggle in the header re-renders
    /// the host's body on the same turn; persisted on write, so `read(from:)`
    /// is the only place the stored representation is interpreted.
    private(set) var collapsed: Set<InspectorSection> {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: Initializers

    /// `defaults` is injectable so the contract can be pinned against a
    /// scratch suite, and so `preview` can hold its own.
    ///
    /// It had a third reason until 3 Aug 2026, and that one was the
    /// load-bearing one: the App pointed it at the UI seed's wiped suite,
    /// because a seeded run reading the developer's own collapsed sections
    /// would fail on a section that is present, correct, and folded shut —
    /// the ambient-`UserDefaults` leak M1 closed for `@AppStorage`, which a
    /// hand-constructed `UserDefaults` does not inherit from
    /// `.defaultAppStorage(_:)`. The UI suite is gone, so the App now passes
    /// `.standard` outright. The seam survives on the previews alone, which
    /// is a weaker reason but a real one.
    ///
    /// Assignment in `init` doesn't fire `didSet`, so a first launch reads the
    /// empty default without writing it back.
    internal init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.collapsed = Self.read(from: defaults)
    }

    // MARK: Internal Methods

    internal func isCollapsed(_ section: InspectorSection) -> Bool {
        collapsed.contains(section)
    }

    internal func toggle(_ section: InspectorSection) {
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
            // Not a defect — this is the retired-section path doing its job.
            // Logged because it is also what a *typo* in a raw value looks
            // like, and the two are indistinguishable from the store.
            Self.logger?.info(
                "Ignored \(stored.count - sections.count, privacy: .public) unknown collapsed-section key(s)"
            )
        }
        return Set(sections)
    }

    /// Sorted, deliberately: a `Set`'s iteration order is not stable across
    /// runs, so an unsorted write would rewrite the same state in a different
    /// order every time — noise in a `defaults` dump, and a diff that means
    /// nothing when reading one.
    private func persist() {
        defaults.set(
            collapsed.map(\.rawValue).sorted(),
            forKey: StorageKeys.collapsedInspectorSections
        )
    }
}

// MARK: Previews

extension InspectorSectionCollapse {

    /// The instance every `#Preview` that renders an inspector section injects.
    ///
    /// `InspectorSectionHeader` reads this from the environment, and a
    /// non-optional `@Environment` traps when read with nothing to find — the
    /// "No Observable object of type … found" the App's own comment describes.
    /// So every preview that renders an inspector section needs one, which is
    /// exactly the recorded build lesson ("a new environment object breaks
    /// every preview that doesn't inject it") arriving on schedule. Uncounted
    /// on purpose: this sentence carried "thirty-one across fourteen files"
    /// and was stale before the milestone that wrote it finished — the
    /// enumerated-caller-list anti-pattern, decaying at exactly the rate a
    /// preview census does.
    ///
    /// Named rather than spelled inline at each site — `SettingsView`'s inline
    /// `SleepInhibitor(defaults:)` literal was the precedent and the shape this
    /// improves on: one site can afford a literal, thirty-one would be
    /// thirty-one chances to reach for `.standard` and edit the developer's own
    /// settings from a canvas. (That literal moved to `SleepInhibitor.preview`
    /// on 4 Aug 2026, adopting this accessor's wipe with it.)
    ///
    /// Computed, not stored: a `static let` on a `@MainActor` type needs its
    /// initializer isolated, and a fresh start per access is the *right*
    /// behaviour here anyway — a preview that toggles a chevron should not
    /// leave that state behind for the next canvas to inherit.
    ///
    /// The `removePersistentDomain` is what makes that sentence true — not
    /// the freshness of the instance, which is what this doc claimed until
    /// the 1 Aug review. A named suite is a real plist and `persist()` writes
    /// every toggle into it, so a fresh instance alone reads the last
    /// canvas's toggles straight back. The UI test seed wiped its own suite
    /// for exactly this reason at exactly this kind of boundary; that seed is
    /// gone, and `SleepInhibitor.preview` adopted the same wipe on 4 Aug 2026 —
    /// two homes now, so this sentence stopped being a uniqueness claim.
    internal static var preview: InspectorSectionCollapse {
        let name = "preview"
        // `!` over a `?? .standard` fallback, `SettingsView`'s sibling
        // spelling: the init only fails for a nil or system-reserved suite
        // name, and the fallback's failure mode was worse than the crash —
        // a canvas silently editing the developer's own defaults, which is
        // the ambient-`UserDefaults` leak M1 exists to prevent. A preview
        // that crashes points at itself; one that leaks points at nothing.
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return InspectorSectionCollapse(defaults: defaults)
    }
}
