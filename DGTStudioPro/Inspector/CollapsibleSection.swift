//
//  CollapsibleSection.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/08/2026.
//

import SwiftUI

/// A `Section` whose header carries the D45′ chevron and whose body obeys it.
///
/// **This type exists to make one specific defect unrepresentable.** A
/// collapsible section is two facts that must agree — which section the chevron
/// toggles, and which section the body checks before rendering — and written by
/// hand at fifteen call sites they are two arguments that can differ. Nothing
/// would catch `.moves` in the header and `.evaluation` in the guard: it
/// compiles, it renders, and it fails only when a reader collapses one section
/// and watches a different one disappear.
///
/// M5 wrote the general form of this as an agreement — *a guard that exists in
/// two places must be computed from one source* — and D40′ sharpened it after
/// two guards agreed perfectly on a value neither could ever produce. The
/// remedy recorded there was "one predicate, called twice". This is the
/// structural version: **one argument, used twice, by a type the host cannot
/// route around.**
///
/// It also keeps the environment read in one place. Without it, seven inspector
/// hosts would each need `@Environment(InspectorSectionCollapse.self)` for no
/// reason other than to write the same `if` — and a host holding the store is a
/// host that can be tempted to write to it.
///
/// `InspectorSectionHeader.section` is the parameter this drives, and it has no
/// other intended caller. A header constructed with a `section:` outside this
/// type gets a chevron that toggles state nothing reads, which is the defect
/// above wearing its other face.
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
