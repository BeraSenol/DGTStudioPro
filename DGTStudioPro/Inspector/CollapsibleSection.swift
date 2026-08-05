import SwiftUI

/// A `Section` whose header carries the D45′ chevron and whose body obeys it.
///
/// **Exists to make one defect unrepresentable.** A collapsible section is two
/// facts that must agree — which section the chevron toggles, and which one the
/// body checks — and hand-written they are two arguments that can differ.
/// `.moves` in the header with `.evaluation` in the guard compiles, renders,
/// and fails only when a reader folds one section and watches another
/// disappear. D40′'s "one predicate, called twice" in its structural form:
/// **one argument, used twice, by a type the host cannot route around.**
///
/// It also keeps the environment out of the hosts — two files hold it, this one
/// gating the body and `InspectorSectionHeader` drawing the chevron. A host
/// holding the store is a host that can be tempted to write to it.
///
/// `InspectorSectionHeader.section` is the parameter this drives and has no
/// other intended caller: a header given a `section:` outside this type gets a
/// chevron toggling state nothing reads — the same defect, other face.
internal struct CollapsibleSection<Content: View, Actions: View>: View {

    // MARK: Stored Properties
    internal let section: InspectorSection
    internal let title: String
    @ViewBuilder internal let content: () -> Content
    @ViewBuilder internal let actions: () -> Actions

    @Environment(InspectorSectionCollapse.self) private var collapse

    // MARK: Initializers
    internal init(
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
    internal var body: some View {
        Section {
            // Not `.opacity` or a zero frame: a collapsed section's rows must
            // not be *built*, because some of them are expensive to build. The
            // Library's PGN row re-serializes the whole game on every body
            // pass, and that section is the longest one precisely because it is
            // the one people fold away.
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
    internal init(
        _ section: InspectorSection,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(section, title: title, content: content, actions: { EmptyView() })
    }
}
