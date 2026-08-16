import SwiftUI

/// The one "nothing selected" surface - nothing forces hosts to agree on an empty
/// state's shape, so one type does. **Render outside the `List`** - inside, it is a top-aligned
/// row with sidebar chrome. The contract is about layout, so non-inspector hosts (the graph
/// window) qualify.
struct InspectorEmptyState: View {
    
    // MARK: Stored Properties
    let title: LocalizedStringKey
    let systemImage: String
    let message: LocalizedStringKey
    let identifier: String
    
    // MARK: Body
    var body: some View {
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

/// All four side by side - the claim is they differ only in words, and a canvas is the only
/// witness that can say so.
#Preview("Every Inspector") {
    HStack(spacing: 0) {
        InspectorEmptyState(
            title: "No Board Connected",
            systemImage: "cable.connector.slash",
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
        // The fourth column was the Rankings inspector's until the merge folded
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

/// One at the narrowest the column can be dragged to - where the description
/// wraps and the symbol/title spacing is actually under load.
#Preview("Single, Minimum Width") {
    InspectorEmptyState(
        title: "No Game Selected",
        systemImage: "document.fill",
        message: "Select a game from the library to view its details and analysis.",
        identifier: AccessibilityID.libraryInspectorEmpty
    )
    .frame(width: 325, height: 420)
}
