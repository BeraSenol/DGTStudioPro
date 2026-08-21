import SwiftUI

/// The one "nothing selected" surface - nothing forces hosts to agree on an empty
/// state's shape, so one type does. **Render outside the `List`** - inside, it is a top-aligned
/// row with sidebar chrome. The contract is about layout, so non-inspector hosts (the graph
/// window) qualify. Inspector-column hosts additionally wrap it in `scrollBacked()` - see that
/// doc for the full-screen toolbar fault the wrapper exists to prevent.
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

// MARK: Scroll Backing

extension InspectorEmptyState {

    /// The inspector-hosted arrangement: the empty state floated over an **empty sidebar
    /// `List`**, so whether-a-scroll-view-sits-under-the-toolbar stays constant while the
    /// column's content flips between empty and loaded.
    ///
    /// **Built as the third suspect in the full-screen toolbar fault and exonerated the same
    /// hour (17 Aug 2026)**: the fault fired with this in place, so the List↔bare flip is not a
    /// *sufficient* explanation - what actually cured the Board was retiring `.inspector` for a
    /// hand-rolled pane (the elimination record lives at `BoardDestination.panelWidth`). Kept
    /// rather than reverted, for now: Library and Players still sit on `.inspector`, the bisect
    /// ladder at `BoardDestination` is re-testing the content-flip rung in isolation, and this
    /// wrapper's fate belongs to that verdict rather than to another same-day round trip.
    ///
    /// The overlay keeps this type's centring contract - the empty state sits *over* the List,
    /// never as a row in it. `.sidebar` matches all three loaded branches, so empty and loaded
    /// share one background. Non-inspector hosts (the graph, analysis-data, info and
    /// view-options windows) stay bare: no toolbar rides their scroll state, and a List
    /// background there would be new chrome.
    func scrollBacked() -> some View {
        List {}
            .listStyle(.sidebar)
            .overlay { self }
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
            message: "Select a game from the Library to view its details and analysis.",
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
            message: "This game has no recorded evaluations, or it is no longer in the Library.",
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
        message: "Select a game from the Library to view its details and analysis.",
        identifier: AccessibilityID.libraryInspectorEmpty
    )
    .frame(width: 325, height: 420)
}
