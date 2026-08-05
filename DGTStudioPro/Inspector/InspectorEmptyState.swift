import SwiftUI

/// The one "nothing selected" surface every inspector renders (D26′).
///
/// The trap it closes: an empty state has no data to shape it, so nothing
/// forces the hosts to agree — they agree only while someone remembers.
/// Centred-and-filling is the platform idiom and the one Board already had.
///
/// Hosts must render this **outside** their `List`. Inside one it is a row
/// again and the divergence returns.
///
/// D46′ gave it its first non-inspector host, the magnifier window. Not
/// renamed: the contract is about *layout* — centred, filling, outside the
/// `List` — which is as true of a window as of a sidebar. Read the name as
/// where it came from rather than where it may be used.
///
/// Copy is `LocalizedStringKey`, not `String`: call sites pass literals, and a
/// `String` would silently resolve to `ContentUnavailableView`'s
/// non-localizing overload — an opt-out nobody decided.
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
        // This frame is what makes the answer "the inspector column" at every
        // call site rather than most of them.
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
        // The fourth column was the Rankings inspector's until D48′ merged
        // it into Players; the graph window's empty state keeps the preview
        // at its stated four-abreast width.
        InspectorEmptyState(
            title: "No Analysis",
            systemImage: "chart.line.uptrend.xyaxis",
            message: "This game has no recorded evaluations, or it is no longer in the library.",
            identifier: AccessibilityID.evaluationWindowEmpty
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
