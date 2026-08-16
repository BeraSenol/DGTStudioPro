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

/// The identifier is **required, no default** - a shared fallback would hand two toolbars one
/// identifier the moment a host forgot. The leading `ToolbarSpacer` is contract: modifiers
/// render in reverse application order, so applying this last puts the toggle trailing-most.
struct InspectorToggleModifier: ViewModifier {
    @Binding var isPresented: Bool
    let identifier: String

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarSpacer()
            InspectorToggleContent(isPresented: $isPresented, identifier: identifier)
        }
    }
}

extension View {
    func inspectorToggle(
        isPresented: Binding<Bool>,
        identifier: String
    ) -> some View {
        modifier(InspectorToggleModifier(isPresented: isPresented, identifier: identifier))
    }
}
