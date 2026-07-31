//
//  InspectorEditButtonView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 27/07/2026.
//

import SwiftUI

/// The pencil that edits what a section header names.
///
/// D22′'s action slot moved out of a row beneath the seven tags and into the
/// header. A row was the wrong home twice over: the rows are a fixed set of
/// seven, so an eighth that is a *verb* reads as part of the roster, and it
/// sits at the far end of the section from the heading it acts on. In the
/// header the affordance is adjacent to its subject — which is where
/// `BoardInspectorView`'s Edit Moves already was, so the two now agree
/// instead of one being documented as a deliberate break from the other.
///
/// Shared rather than open-coded per host for `InspectorEmptyState`'s reason
/// (D26′): the chrome is small enough that each host would happily carry its
/// own copy, and nothing would then hold two — soon three — pencils to the
/// same glyph, size and hit target. What the host still owns is the part that
/// genuinely differs: the action, the registry identifier, and the words.
///
/// `label` feeds both `.help` and `.accessibilityLabel`, because a glyph-only
/// button gives neither anything to fall back on — VoiceOver would otherwise
/// announce "pencil". One string, so tooltip and spoken label cannot disagree.
/// It is a `LocalizedStringKey` for `InspectorEmptyState`'s reason: a `String`
/// parameter silently resolves to the non-localizing overloads.
///
/// The identifier takes no default (the `dgtConnectionToolbar` lesson): a
/// shared fallback would hand two inspectors' pencils the same identifier,
/// while a required parameter makes forgetting one a compile error.
internal struct InspectorEditButtonView: View {
    
    // MARK: Stored Properties
    internal let label: LocalizedStringKey
    internal let identifier: String
    internal let action: () -> Void
    
    // MARK: Body
    internal var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                // The label's own frame is the hit area under
                // `.buttonStyle(.borderless)`, and an SF Symbol's frame is
                // mostly transparent; `.contentShape` makes the whole box
                // clickable rather than the drawn strokes.
                //
                // Spelled `Rectangle()` rather than the shorter `.rect` to
                // match the app's three existing sites. Both compile; two
                // spellings of one shape is how a grep for a pattern starts
                // missing half of it.
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        // Stated, not inherited: a sidebar section header sets a small
        // secondary font, and a glyph rendered at that size is an ~11 pt
        // mouse target. The heading stays header-sized; the control renders
        // at control size, which is what AppKit's own header accessories do.
        //
        // Load-bearing alone since the trailing padding left for
        // `InspectorSectionHeader.actionsInset`: that padding widened the
        // target as a side effect of insetting the edge, and this line is now
        // the only thing sizing it. Shrinking the font here shrinks the hit
        // box, with nothing else to make up the difference.
        .font(.body)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: Previews

/// In the surface it exists for, at the inspector's own width, with a
/// headline long enough to be doing the truncating. The claim under witness
/// is that the pencil stays pinned trailing and the header stays one line
/// tall — what `SevenTagRosterSection`'s `lineLimit(1)` buys.
#Preview("In a Section Header") {
    List {
        SevenTagRosterSection(
            roster: RosterSummary(
                event: "World Championship",
                site: "Dubai",
                date: Date(timeIntervalSince1970: 1_720_000_000),
                round: 7,
                white: "Carlsen, Magnus",
                black: "Nepomniachtchi, Ian",
                result: .ongoing
            ),
            headline: "Reviewing 7. Magnus Carlsen vs Ian Nepomniachtchi"
        ) {
            InspectorEditButtonView(
                label: "Edit Info",
                identifier: AccessibilityID.boardEditInfoButton,
                action: {}
            )
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 320)
}

/// The narrowest the column drags to, beside a header with no action at all —
/// the two states of the same section, which is where a shift in header
/// height or baseline shows up.
#Preview("Narrow — With and Without") {
    List {
        SevenTagRosterSection(
            roster: RosterSummary(
                event: "Club Championship",
                site: "Antwerp",
                date: Date(timeIntervalSince1970: 1_720_000_000),
                round: 101,
                white: "Senol, Bera",
                black: "Reinaud, Lorenzo",
                result: .ongoing
            ),
            headline: "Recording 101. Bera Senol vs Lorenzo Reinaud"
        ) {
            InspectorEditButtonView(
                label: "Edit Details",
                identifier: AccessibilityID.liveInspectorEditDetails,
                action: {}
            )
        }
        SevenTagRosterSection(roster: nil, headline: "Game Details")
    }
    .listStyle(.sidebar)
    .frame(width: 260, height: 560)
}
