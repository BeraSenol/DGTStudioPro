//
//  OpeningSection.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 30/07/2026.
//

import SwiftUI

/// A game's classified opening as one sidebar section (D34′, D35′) — shared
/// by the two inspectors that show an archived game, the Board's review
/// inspector and the Library's.
///
/// Shared for the same reason `SevenTagRosterSection` is: two inspectors free
/// to disagree about what an unclassified game looks like will eventually
/// disagree, and D26′'s whole point is that a divergence should be a
/// compile-visible choice rather than a drift. The live inspector
/// deliberately doesn't render it — a game in progress has an opening, but
/// nothing classifies it until it archives, and a section that is always
/// "—" during play is worse than no section.
///
/// **Row count varies, unlike the roster's.** The seven tags always render
/// all seven because the *standard* fixes that set — an unset tag prints
/// PGN's own unknown vocabulary rather than dropping the line. These rows are
/// ours, so an opening with no variation simply has no Variation row. The
/// alternative would be a third placeholder meaning "classified, and this
/// opening has no variation", which is a distinction no reader asked for.
internal struct OpeningSection: View {

    // MARK: Static Constants

    /// Shown when there is no classified opening — *and* when there is no
    /// game at all, which is the Board inspector's state before one loads.
    ///
    /// One placeholder, where D22′'s roster next door needs two. The roster
    /// distinguishes "this game doesn't say" (`?`) from "there is no game to
    /// ask" (`—`) because PGN has its own vocabulary for an unset tag. An
    /// opening is not a tag and has no such vocabulary: "no game" and "no
    /// opening" are both just nothing to show, and inventing a second glyph
    /// would be drawing a distinction no reader is looking for.
    ///
    /// The same glyph as `SevenTagRosterSection.noGamePlaceholder`, and
    /// deliberately its own constant rather than a shared one: both mean
    /// "the app has nothing to put here" — as opposed to `RosterSummary`'s
    /// `?`, which means "the game doesn't say" — but they are two sections'
    /// two decisions that agree today, not one decision with two call sites.
    /// Collapsing them would make a future divergence a merge conflict in
    /// the wrong file.
    private static var unclassifiedPlaceholder: String { RosterSummary.displayUnknown }

    // MARK: Stored Properties

    internal let opening: ECOOpening?

    // MARK: Body

    /// Collapses as `.opening` (D45′), shared between the Board and Library
    /// inspectors for `SevenTagRosterSection`'s reason — one section rendered
    /// twice, not two that look alike.
    internal var body: some View {
        CollapsibleSection(.opening, title: "Opening") {
            if let opening {
                LabeledContent("ECO", value: opening.code)
                LabeledContent("Opening", value: opening.family)
                // Always present, placeholder when nil (by request). D22′
                // recorded this section's varying row count as its deliberate
                // difference from `SevenTagRosterSection`, whose seven are
                // fixed by the standard "while these rows are ours" — and ours
                // is what makes this a choice rather than a violation. A row
                // that appears and disappears makes the section's height move
                // between games, and a reader scanning a variation down a list
                // of games is reading a row that isn't always in the same
                // place. The absent case is now stated rather than implied,
                // which is what the placeholder is for.
                //
                // D35′ is untouched underneath: nil is still the one spelling
                // of "no variation", and `fullName` still omits it. This is a
                // rendering decision, not a data one.
                LabeledContent(
                    "Variation",
                    value: opening.variation ?? Self.unclassifiedPlaceholder
                )
            } else {
                LabeledContent("Opening", value: Self.unclassifiedPlaceholder)
            }
        }
    }
}

// MARK: Previews

/// The three-row shape — a named line deep enough to carry a variation.
#Preview("Named Variation") {
    List {
        OpeningSection(
            opening: ECOOpening(
                code: "C18",
                name: "French Defense: Winawer Variation, Poisoned Pawn Variation"
            )
        )
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 200)
    .environment(InspectorSectionCollapse.preview)
}

/// A bare family drops its Variation row rather than inventing a placeholder
/// for it — the row-count decision, and the only place it's visible.
#Preview("Bare Family") {
    List {
        OpeningSection(opening: ECOOpening(code: "C60", name: "Ruy Lopez"))
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 200)
    .environment(InspectorSectionCollapse.preview)
}

/// The em dash: no classified opening. Worth opening beside "Bare Family" —
/// the difference between "no variation" and "no opening" is the whole
/// reason the row count moves.
#Preview("Unclassified") {
    List {
        OpeningSection(opening: nil)
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 200)
    .environment(InspectorSectionCollapse.preview)
}
