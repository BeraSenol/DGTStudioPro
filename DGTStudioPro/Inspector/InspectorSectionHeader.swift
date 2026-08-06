import SwiftUI

/// A sidebar section header that names the thing the section is about, with
/// the action on that thing trailing it.
///
/// Extracted from `SevenTagRosterSection` the moment a second inspector wanted
/// the same header. Left inline it would have been copied per host, and the
/// copies would agree only while someone remembered — `InspectorEmptyState`'s
/// argument (D26′) one layer up.
///
/// `title` is a `String`, not a `LocalizedStringKey`, and that is the point of
/// the type: these headers carry *data* — a game's name, a player's name, a
/// formatted headline — not copy. A `LocalizedStringKey` would send a player's
/// name through the strings table looking for a translation.
///
/// One line, truncating: a header with a control pinned beside it needs a
/// settled height, and every title here is a name that also appears in the rows
/// below, or a headline whose parts do.
///
/// The action is a `@ViewBuilder` slot rather than an `onEdit` closure, so each
/// host keeps its own identifier, wording and action. No single control is "what
/// hosts pass" — this doc claimed `InspectorEditButtonView` was, which a menu
/// and a glyph pair each outgrew. The slot's real range is witnessed by the
/// *Actions — Every Arity* preview below.
internal struct InspectorSectionHeader<Actions: View>: View {
    
    // MARK: Type Properties
    
    /// How far the header's trailing edge sits from the inspector's, and so
    /// how far the outermost control sits from it.
    ///
    /// It lived on `InspectorEditButtonView` as `.padding(.trailing, 10)` under
    /// a doc reading "stated here and nowhere else" — true of the *number*,
    /// false of the *job*. That padding both inset the header's trailing control
    /// and widened the pencil's hit target, which coincide only while the pencil
    /// is last. M5's Players header put a menu after it, and the edge inset
    /// silently transferred to a control carrying none: three distances from one
    /// edge — 10 pt at the lone pencils, 8 pt at the Library's PGN glyph pair
    /// (which had quietly added its own), 0 pt at the actions menu.
    ///
    /// Owning it here is what makes a host unable to get it wrong, whatever goes
    /// into the actions slot and however much. `InspectorEditButtonView` keeps
    /// the hit target, the half that genuinely belonged to it.
    ///
    /// Applied to the whole row rather than to `actions()`, so an actionless
    /// header gives up these points too. Deliberate, and the distinction
    /// matters: a **bare** `EmptyView` is flattened out of a `ViewBuilder` list
    /// and lays nothing out, but an `EmptyView` **under a modifier** is a
    /// `ModifiedContent` — a different type, no longer the one SwiftUI
    /// special-cases. So `actions().padding(…)` would be a layout claim nobody
    /// has checked, where `HStack(spacing: 12) { chevron; actions() }` rests
    /// only on the flattening.
    ///
    /// Computed, not stored: this type is generic and **generic types cannot
    /// have stored static properties**. `SevenTagRosterSection` records the same
    /// constraint at `noGamePlaceholder` — one scroll away, and re-learned from
    /// the compiler anyway.
    internal static var actionsInset: CGFloat { 12 }
    
    // MARK: Stored Properties
    internal let title: String
    
    /// The section's stored identity, or `nil` for a header that does not
    /// collapse. Optional rather than required because "collapsible" is a
    /// property of the section, not of the header type — and because a
    /// required parameter would force every future header to mint an
    /// `InspectorSection` case before it could render at all.
    internal let section: InspectorSection?
    
    @ViewBuilder internal let actions: () -> Actions
    
    @Environment(InspectorSectionCollapse.self) private var collapse
    
    // MARK: Initializers
    internal init(
        _ title: String,
        section: InspectorSection? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.section = section
        self.actions = actions
    }
    
    // MARK: Body
    internal var body: some View {
        HStack(spacing: 0) {
            Text(title)
            // Stated because a `List` section header uppercases by
            // default on some styles, and a game or player name is not
            // a label to be shouted.
                .textCase(nil)
                .lineLimit(1)
            Spacer(minLength: 8)
            // The chevron sits **trailing** of the actions — reversed
            // 2 Aug 2026 from D45′'s original order (chevron leading, verb
            // rightmost) in the same pass that widened `actionsInset`. What
            // the new order buys: the disclosure sits at one fixed distance
            // from the edge in **every** section, however many action glyphs
            // precede it, so the fold affordances read as one column down the
            // inspector. The cost, accepted: action glyphs are no longer
            // edge-aligned across sections with different arities. The 3 Aug
            // audit found this comment still asserting the old order — the
            // exact comment-says-leading-while-code-lists-otherwise defect
            // the old Library disclosure had, which D45′ was written to end.
            // The instructions' D45′ anchor records the reversal.
            HStack(spacing: 12) {
                actions()
                if let section {
                    disclosure(for: section)
                }
            }
        }
        .padding(.trailing, Self.actionsInset)
    }
    
    // MARK: Instance Methods
    
    /// One chevron rotated rather than two symbols swapped, so the state change
    /// is a continuous motion the eye tracks instead of a substitution it has
    /// to re-read. Inherited wholesale from the Library's PGN disclosure, which
    /// is the control this replaces.
    private func disclosure(for section: InspectorSection) -> some View {
        let isCollapsed = collapse.isCollapsed(section)
        // Annotated `String` on purpose, and it is the inverse of the choice
        // `InspectorEditButtonView` makes one file over. That type's `label`
        // is a `LocalizedStringKey` because it carries *copy* ("Edit Info"),
        // and a `String` there would silently pick the non-localizing
        // overloads. Here the label interpolates `title`, which is **data** —
        // a game's name, a player's name — so a `LocalizedStringKey` would
        // send "Hide Bera Senol vs Lorenzo Reinaud" to the strings table
        // looking for a translation. That is the exact trap this file's own
        // header doc names as the reason `title` is not a `LocalizedStringKey`,
        // and interpolating it into one would have re-opened it from the side.
        let label: String = isCollapsed ? "Show \(title)" : "Hide \(title)"
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                collapse.toggle(section)
            }
        } label: {
            Image(systemName: "chevron.right")
                .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        // `InspectorEditButtonView`'s reason: a glyph at header font size is
        // an ~11 pt mouse target.
        .font(.body)
        .help(label)
        .accessibilityLabel(label)
        // The registry takes the raw value — the String-only rule minted when
        // it compiled into the UI test target too (kept after the suite left,
        // D51′; the registry header owns that call). This is the only caller,
        // and it holds the real thing.
        .accessibilityIdentifier(AccessibilityID.inspectorSectionDisclosure(section.rawValue))
    }
}

// MARK: Convenience

extension InspectorSectionHeader where Actions == EmptyView {
    
    /// A header with nothing to act on — the actionless sections (Opening,
    /// Evaluation, Moves, Recent Games…), and any section whose title is a
    /// label rather than a subject. (This read "Players and Rankings today"
    /// until D48′ retired Rankings and the 3 Aug audit caught the tense.)
    ///
    /// It may still collapse: a chevron is not an action on the section's
    /// subject, it is an action on the section, which is why it lives in the
    /// header's own body rather than in the slot a host fills.
    internal init(_ title: String, section: InspectorSection? = nil) {
        self.init(title, section: section, actions: { EmptyView() })
    }
}

// MARK: Previews

/// Four of the five inspectors' headers in one column, two with an action and
/// two without — the live inspector's is the Board's shape with different
/// words, so it earns no fifth row. The type's claim is that a header carrying
/// a control and one not carrying one are the same height and the same
/// baseline; stacked is the only way to see that, and a name long enough to
/// truncate is the case that breaks it.
#Preview("Every Inspector Header") {
    List {
        Section {
            Text("Event, Site, Date, Round, White, Black, Result")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Bera Senol vs Lorenzo Baelus") {
                InspectorEditButtonView(
                    label: "Rename",
                    identifier: AccessibilityID.libraryInspectorRename,
                    action: {}
                )
            }
        }
        Section {
            Text("The Board inspector's headline, long enough to truncate")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader(
                "Reviewing 7. Magnus Carlsen vs Ian Nepomniachtchi"
            ) {
                InspectorEditButtonView(
                    // Was "Edit Info" / `board.editInfo` until D57′ removed
                    // that affordance. Repointed at the live inspector's Edit Details
                    // pencil rather than left citing a deleted identifier —
                    // and the app's *one* surviving `InspectorEditButtonView`
                    // is the honest thing for this canvas to show, since a
                    // preview witnessing an arrangement the app has retired
                    // reads as evidence the arrangement is still checked.
                    label: "Edit Details",
                    identifier: AccessibilityID.liveInspectorEditDetails,
                    action: {}
                )
            }
        }
        Section {
            Text("Games, Win Rate, Mates Delivered…")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Bera Senol")
        }
        Section {
            Text("Rank, Wins, Record, Rating…")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Christos Dermentzoglou")
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 420)
    .environment(InspectorSectionCollapse.preview)
}

/// Every arity of the actions slot the app actually passes, stacked so their
/// trailing edges are readable against each other — one control, two, and
/// none, with and without a chevron.
///
/// This is the preview the type should have had. `actionsInset` is a claim
/// about *every* header's outermost control, and until M8 the only witness was
/// four headers all passing a lone pencil — the one arity where the old
/// arrangement happened to be right. The multi-control row is the one that was
/// wrong for a month: the Players shape put its menu flush against the edge,
/// and the Library shape sat two points inside everything else.
///
/// What to look at is a vertical line, not a row: if any one of the trailing
/// controls is out of column with the others, the inset has escaped its single
/// statement again.
///
/// **Kept honest 4 Aug.** This preview carried a "Pencil and Menu" row long
/// after the app stopped having one — D52′ removed the Players ellipsis menu
/// and M10 removed the pencil beside it, leaving a witness for an arity
/// nothing passes. The header this row shows now is the Library's PGN header,
/// which is the app's only remaining two-verb slot. A preview that shows an
/// arrangement the app has retired is worse than no preview: it reads as
/// evidence that the arrangement is still checked.
#Preview("Actions, Every Arity") {
    List {
        Section {
            Text("One control, four inspectors' pencils.")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Lone Pencil") {
                InspectorEditButtonView(
                    // Was "Edit Info" / `board.editInfo` until D57′ removed
                    // that affordance. Repointed at the live inspector's Edit Details
                    // pencil rather than left citing a deleted identifier —
                    // and the app's *one* surviving `InspectorEditButtonView`
                    // is the honest thing for this canvas to show, since a
                    // preview witnessing an arrangement the app has retired
                    // reads as evidence the arrangement is still checked.
                    label: "Edit Details",
                    identifier: AccessibilityID.liveInspectorEditDetails,
                    action: {}
                )
            }
        }
        Section {
            Text("Chevron, pencil, glyph, the Library's PGN header (D54′).")
                .foregroundStyle(.secondary)
        } header: {
            // The app's one multi-control header, and the only place two verbs
            // share a slot since D52′ took the Players menu and M10 took its
            // pencil. The pencil leads the glyph because the edit verb is the
            // section's verb and Copy is a convenience on what it shows.
            InspectorSectionHeader("Pencil and Glyph", section: .pgn) {
                InspectorEditButtonView(
                    label: "Edit Details",
                    identifier: AccessibilityID.liveInspectorEditDetails,
                    action: {}
                )
                Button { } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .font(.body)
            }
        }
        Section {
            Text("No actions, Opening, Evaluation, Moves, Recent Games…")
                .foregroundStyle(.secondary)
        } header: {
            InspectorSectionHeader("Nothing To Act On")
        }
        Section {
            Text("A chevron and nothing else.")
                .foregroundStyle(.secondary)
        } header: {
            // The arity worth looking hardest at, and the one thing in D45′
            // written from reasoning rather than from a compiler. The trailing
            // cluster is `HStack(spacing: 12) { actions(); chevron }` (order
            // reversed 2 Aug 2026 — see the body), and with no actions the
            // slot resolves to `EmptyView` — which should contribute no
            // subview and therefore no 12 pt of spacing, because spacing
            // applies *between* subviews and there is only one either way
            // the pair is ordered.
            //
            // Should. This preview is where that stops being an argument: if
            // this chevron sits 12 pt inside the one above it, `EmptyView` is
            // being laid out and the gap needs to move onto the chevron under
            // a condition instead.
            InspectorSectionHeader("Collapsible, No Actions", section: .recentGames)
        }
    }
    .listStyle(.sidebar)
    .frame(width: 300, height: 540)
    .environment(InspectorSectionCollapse.preview)
}
