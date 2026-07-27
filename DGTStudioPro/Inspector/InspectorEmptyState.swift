//
//  InspectorEmptyState.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 27/07/2026.
//

import SwiftUI

/// The one "nothing selected" surface every inspector renders (D26′).
///
/// Not a wrapper for its own sake. Board filled its column with a centred
/// `ContentUnavailableView`; Library and Players put the same view *inside*
/// a `List`, where it becomes a top-aligned row with sidebar chrome behind
/// it; Rankings rendered a bare secondary `Text` under a section header with
/// no symbol at all. Centred-and-filling is the platform idiom and the one
/// Board already had, so it wins.
///
/// The trap this closes: an empty state is the one part of an inspector with
/// no data to shape it, so nothing forces the four to agree — they agree only
/// while someone remembers. A shared type makes it structural: D22′'s move,
/// applied to the empty case.
///
/// Hosts must render this **outside** their `List`. Inside one it is a row
/// again and the divergence returns.
///
/// Copy is `LocalizedStringKey`, not `String`: the call sites pass literals,
/// and a `String` parameter would silently resolve to
/// `ContentUnavailableView`'s non-localizing overload instead — an opt-out
/// nobody decided.
///
/// The identifier takes no default (the `dgtConnectionToolbar` lesson): a
/// shared fallback would hand two inspectors the same identifier, while a
/// required parameter makes forgetting one a compile error.
internal struct InspectorEmptyState: View {
    
    // MARK: Stored Properties
    internal let title: LocalizedStringKey
    internal let systemImage: String
    internal let message: LocalizedStringKey
    internal let identifier: String
    
    // MARK: Body
    internal var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
        // Stated, not inherited: `ContentUnavailableView` centres within
        // whatever it is handed, and what it is handed is the host's choice.
        // This frame is what makes the answer "the inspector column" at all
        // four call sites rather than three.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: Previews

/// All four side by side at the inspector's own minimum width. The type's
/// whole claim is that these differ only in their words, and a canvas showing
/// them together is the only witness that can say so — a drift in alignment,
/// symbol weight or description wrapping reads as a mismatch here rather than
/// as something noticed months later in a screenshot.
#Preview("Every Inspector") {
    HStack(spacing: 0) {
        InspectorEmptyState(
            title: "No Board Connected",
            systemImage: "cable.connector.horizontal",
            message: "Connect your DGT board to record games live.",
            identifier: AccessibilityID.liveInspectorNoBoard
        )
        Divider()
        InspectorEmptyState(
            title: "No Game Selected",
            systemImage: "document.fill",
            message: "Select a game from the library to view its details and analysis.",
            identifier: AccessibilityID.libraryInspectorEmpty
        )
        Divider()
        InspectorEmptyState(
            title: "No Player Selected",
            systemImage: "person.fill",
            message: "Select a player to view their profile and recent games.",
            identifier: AccessibilityID.playersInspectorEmpty
        )
        Divider()
        InspectorEmptyState(
            title: "No Player Selected",
            systemImage: "list.number",
            message: "Select a player to see their rank and rating trend.",
            identifier: AccessibilityID.rankingsInspectorEmpty
        )
    }
    .frame(width: 4 * 325, height: 420)
}

/// One at the narrowest the column can be dragged to — where the description
/// wraps and the symbol/title spacing is actually under load.
#Preview("Single — Minimum Width") {
    InspectorEmptyState(
        title: "No Game Selected",
        systemImage: "document.fill",
        message: "Select a game from the library to view its details and analysis.",
        identifier: AccessibilityID.libraryInspectorEmpty
    )
    .frame(width: 325, height: 420)
}
