import SwiftUI

/// A game's classified opening as one section, shared by the Board review and Library
/// inspectors. The live inspector deliberately doesn't render it.
struct OpeningSection: View {

    // MARK: Static Constants

    /// Shown for no classified opening *and* no game at all — an opening is not a tag and has no
    /// `?` vocabulary. Its own constant beside `SevenTagRosterSection`'s: two decisions that agree
    /// today, not one with two call sites.
    private static var unclassifiedPlaceholder: String { RosterSummary.displayUnknown }

    // MARK: Stored Properties

    let opening: ECOOpening?

    // MARK: Body

    /// Collapses as `.opening` — one section rendered twice, not two that look alike.
    var body: some View {
        CollapsibleSection(.opening, title: "Opening") {
            if let opening {
                LabeledContent("ECO", value: opening.code)
                LabeledContent("Opening", value: opening.family)
                // Always present, placeholder when nil (by request). The varying row count is this section's
                // deliberate difference from the roster's fixed seven.
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

/// A bare family drops its Variation row rather than inventing a placeholder — the row-count
/// decision's one visible place.
#Preview("Bare Family") {
    List {
        OpeningSection(opening: ECOOpening(code: "C60", name: "Ruy Lopez"))
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 200)
    .environment(InspectorSectionCollapse.preview)
}

/// The em dash beside "Bare Family" — "no variation" vs. "no opening" is why the row count moves.
#Preview("Unclassified") {
    List {
        OpeningSection(opening: nil)
    }
    .listStyle(.sidebar)
    .frame(width: 340, height: 200)
    .environment(InspectorSectionCollapse.preview)
}
