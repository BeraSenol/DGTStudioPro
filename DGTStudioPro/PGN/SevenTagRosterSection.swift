//
//  SevenTagRosterSection.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

import SwiftUI

/// The Seven Tag Roster as one sidebar section (D22′): a headline, the seven
/// tags in the standard's order, then whatever action the host wants beneath
/// them. Shared by the review inspector, the live inspector, and — when its
/// Open/name rows move out — the Library inspector.
///
/// Rows are driven by `SevenTagRoster.allCases`, so a host cannot render six
/// tags or invent an order. The labels are the PGN tag names verbatim and are
/// deliberately not localized: they're the standard's identifiers, the same
/// strings that appear in the file the user exports.
///
/// The action slot is a `@ViewBuilder` rather than an `onEdit` closure so each
/// host keeps its own title and accessibility identifier — the live
/// inspector's "Edit Details…" is `live.inspector.editDetails`, and the
/// review side's eventual "Edit Info…" will be its own registry entry, not a
/// shared one pretending two buttons are the same button.
internal struct SevenTagRosterSection<Actions: View>: View {
    
    // MARK: Static Constants
    
    /// No game at all — distinct from `RosterSummary.unknownTag`'s "this
    /// game doesn't say". Preserves the Board inspector's existing empty
    /// state exactly.
    private static var noGamePlaceholder: String { "—" }
    
    // MARK: Stored Properties
    
    internal let roster: RosterSummary?
    internal let headline: String
    @ViewBuilder internal let actions: () -> Actions
    
    // MARK: Body
    
    internal var body: some View {
        Section {
            ForEach(SevenTagRoster.allCases, id: \.self) { tag in
                LabeledContent(tag.rawValue, value: value(for: tag))
            }
            
            actions()
        } header: {
            Text(headline)
                .textCase(nil)
        }
    }
    
    private func value(for tag: SevenTagRoster) -> String {
        roster?[tag] ?? Self.noGamePlaceholder
    }
}

// MARK: Convenience

extension SevenTagRosterSection where Actions == EmptyView {
    
    /// A read-only roster — the review inspector today.
    internal init(roster: RosterSummary?, headline: String) {
        self.init(roster: roster, headline: headline, actions: { EmptyView() })
    }
}
