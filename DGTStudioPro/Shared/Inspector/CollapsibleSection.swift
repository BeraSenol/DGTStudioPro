import SwiftUI

/// A `Section` whose header carries the D45′ chevron and whose body obeys it. **Exists to make
/// one defect unrepresentable**: header-toggles-X-while-body-checks-Y compiles and renders —
/// one argument, used twice, by a type the host cannot route around.
struct CollapsibleSection<Content: View, Actions: View>: View {

    // MARK: Stored Properties
    let section: InspectorSection
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions

    @Environment(InspectorSectionCollapse.self) private var collapse

    // MARK: Initializers
    init(
        _ section: InspectorSection,
        title: String,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.section = section
        self.title = title
        self.content = content
        self.actions = actions
    }

    // MARK: Body
    var body: some View {
        Section {
            // Not `.opacity` or a zero frame: a collapsed section's rows must not be *built* — the PGN row
            // re-serializes the whole game per body pass.
            if !collapse.isCollapsed(section) {
                content()
            }
        } header: {
            InspectorSectionHeader(title, section: section, actions: actions)
        }
    }
}

// MARK: Convenience

extension CollapsibleSection where Actions == EmptyView {

    /// A collapsible section with nothing to act on — most of them. The
    /// chevron is not an action on the section's subject, so a section can
    /// collapse without offering a verb.
    init(
        _ section: InspectorSection,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(section, title: title, content: content, actions: { EmptyView() })
    }
}
