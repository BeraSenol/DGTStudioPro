//
//  Inspector+Toolbar.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

import SwiftUI

/// The toggle as `ToolbarContent`, so a host composes it into its **own**
/// `ToolbarContentBuilder` alongside its other items instead of stacking a
/// second `.toolbar` modifier.
///
/// Not tidiness. Items merged from separate `.toolbar` modifiers arrive
/// without a region boundary SwiftUI can act on, and an undivided toolbar
/// keeps the `.inspector` column tucked beneath it. The Library — the one
/// destination whose inspector draws full height, up through the toolbar — is
/// also the one whose toggle lives in the same builder as everything else,
/// with a `ToolbarSpacer` marking the break. Players and Board both
/// stack modifiers and both get the short column. Composing is what puts the
/// trailing items in the inspector's own toolbar region.
///
/// Callers still own the `ToolbarSpacer` that precedes it, because only the
/// caller knows what it is separating from.
internal struct InspectorToggleContent: ToolbarContent {
    @Binding internal var isPresented: Bool
    internal let identifier: String

    /// Set when the destination's current view mode renders its own detail
    /// pane (`CollectionViewMode.ownsDetailPane`), which makes the window's
    /// inspector a second copy of the same facts — and, in columns mode,
    /// pushes the layout past the window's width.
    ///
    /// Defaulted, unlike `identifier`. That parameter is required precisely
    /// because a default would be invisible to the registry's enforcement
    /// grep; this one is a plain behaviour flag with an obviously correct
    /// resting value, and demanding `isDisabled: false` at the Board's call
    /// site would be ceremony over a destination that has no view modes at
    /// all.
    internal var isDisabled = false

    /// The reason, shown on hover when disabled. Carried here rather than
    /// left to the caller so the explanation cannot go missing at one of the
    /// two hosts — a dimmed control with no help text is the thing that reads
    /// as a bug.
    internal var disabledReason: LocalizedStringKey = "This view shows details in its own pane"

    internal var body: some ToolbarContent {
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

/// The identifier is deliberately **required**, with no default: a shared
/// fallback would hand two destinations' toolbars the same identifier the
/// moment a host forgot to pass one, and a parameter default is invisible to
/// the registry's enforcement grep (the `board.connectButton` lesson, second
/// occurrence). Required means forgetting is a compile error.
///
/// The leading `ToolbarSpacer` is part of the contract, not decoration: the
/// inspector toggle is the trailing-most control in every destination that
/// has one, and it acts on the *window*, not on the destination's content —
/// so it belongs to its own group rather than sharing a pill with Flip Board
/// and Connect. The Library, which open-codes its toggle, already spaced it
/// this way; putting the spacer here rather than at each call site is what
/// stops Board from being the one that forgets.
///
/// **Apply this modifier innermost.** Items from separate `.toolbar` modifiers
/// render in reverse application order, so a host that applies this one last
/// gets the toggle *leading*, where the spacer has nothing on its left and
/// collapses — the toggle then shares a pill with everything else, which is
/// the exact symptom this modifier exists to prevent. Both current hosts
/// (Board, Players) apply it above their `.toolbar { … }`.
internal struct InspectorToggleModifier: ViewModifier {
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
    internal func inspectorToggle(
        isPresented: Binding<Bool>,
        identifier: String
    ) -> some View {
        modifier(InspectorToggleModifier(isPresented: isPresented, identifier: identifier))
    }
}
