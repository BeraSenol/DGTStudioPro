import SwiftUI

/// The toggle as `ToolbarContent`, composed into the host's own builder - items merged from
/// separate `.toolbar` modifiers arrive with no region boundary. Callers own the preceding
/// `ToolbarSpacer`.
struct InspectorToggleContent: ToolbarContent {
    @Binding var isPresented: Bool
    let identifier: String

    /// Set when the mode renders its own detail pane - the inspector would be a second copy of the
    /// same facts.
    var isDisabled = false

    /// The hover reason when disabled, carried here so the explanation cannot go missing at one
    /// host - a dimmed control with no help reads as a bug.
    var disabledReason: LocalizedStringKey = "This view shows details in its own pane"

    var body: some ToolbarContent {
        ToolbarItem {
            Button {
                isPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .disabled(isDisabled)
            .help(isDisabled ? disabledReason : "Show or hide the inspector")
            .accessibilityIdentifier(identifier)
        }
    }
}

// (`InspectorToggleModifier` and `View.inspectorToggle(isPresented:identifier:)` stood here until
// 18 Aug 2026 - a `ViewModifier` wrapper that applied its own `.toolbar` carrying a `ToolbarSpacer`
// and the content above. Every host composes `InspectorToggleContent` into its own builder instead,
// which is what the type's own note says the arrangement is; the wrapper had no caller. Removed by
// dead-code scan, not by a change of design.)
