import SwiftUI

/// The Players destination's context menu, once — `GameActionsMenu`'s twin,
/// for its reason.
///
/// Three hosts had three hand-built copies of the same two items, which is how
/// the Library's three drifted into three renderings of five verbs. Two items is
/// not much duplication; the point is that a divergence should be a
/// compile-visible choice, and at three call sites it never is.
///
/// **Single-subject, deliberately, where the Library's menu counts.** Both verbs
/// act on one player — "Show in Library" filters to a name, Get Info describes
/// one row — so a selection of nine means nothing to either. The asymmetry with
/// `GameActionsMenu` is the destinations', not an inconsistency between types.
///
/// D9′ holds underneath: the registry is machine-managed and players have no
/// destructive actions, so there is no `Divider()` and nothing below it.
///
/// Both items carry a shortcut, because collection-destination parity is an
/// invariant and keys stopping at the destination boundary is the half-
/// difference it exists to catch. Get Info keeps ⌘I from `GetInfoMenuItem`;
/// Show in Library takes **⇧⌘L**, shifted because plain ⌘L is what a future
/// find-or-filter verb will want and this is navigation, not a primary action.
///
/// `GameActionsMenu`'s doc carries the standing caveat for both types: these
/// keys are known to *render* and not yet known to fire with the menu shut.
internal struct PlayerActionsMenu: View {

    // MARK: Stored Properties

    /// `Player.normalizedName` — the key every Players surface addresses rows
    /// by, since the view modes render `PlayerStats` folds rather than models.
    internal let key: PlayerStats.ID

    /// Optional because navigation is the *host's* capability, not the
    /// player's: `PlayerCardView` is rendered by hosts that offer no Library
    /// route, and forcing a closure would make them pass an empty one — a menu
    /// item that looks live and does nothing, which is the D40′ shape.
    ///
    /// Absorbed here rather than left at the three call sites, which is the
    /// whole point of the type: the card carried this conditional by hand and
    /// the other two hosts did not, so "is Show in Library ever hidden?" had
    /// three answers. Get Info sits outside the guard because a row always
    /// knows which player it draws — a menu whose only item is conditional is a
    /// menu that is sometimes empty.
    internal var onShowInLibrary: ((PlayerStats.ID) -> Void)? = nil

    // MARK: Body
    internal var body: some View {
        GetInfoMenuItem(
            request: .player(key: key),
            identifier: AccessibilityID.getInfoMenuItem(Destination.players.rawValue)
        )

        if let onShowInLibrary {
            Divider()
            
            Button {
                onShowInLibrary(key)
            } label: {
                Label("Show in Library", systemImage: "books.vertical")
            }
            // Rides inside the optional-closure guard on purpose: a host with
            // no Library route does not render this item, and must therefore
            // not advertise its key either. A shortcut surviving the affordance
            // it belongs to is the D40′ shape wearing a key equivalent.
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .accessibilityIdentifier(AccessibilityID.contextShowInLibrary)
        }
    }
}

// MARK: Previews

/// Inside a `Menu` for `GameActionsMenu`'s reason: a canvas has no right-click,
/// so `.contextMenu` would render nothing and witness the call site rather than
/// the content.
///
/// Both arities, because the optional closure is the only thing this type
/// decides and the two rows are what it decides between. The second is the
/// `PlayerCardView` case — a host that draws a player but offers no Library
/// route — and the claim under witness is that it shows Get Info **alone**
/// rather than showing a disabled row or an empty menu.
#Preview("With and Without Navigation") {
    VStack(alignment: .leading, spacing: 16) {
        Menu("Host With Navigation") {
            PlayerActionsMenu(key: "carlsen, magnus", onShowInLibrary: { _ in })
        }
        Menu("Host Without") {
            PlayerActionsMenu(key: "carlsen, magnus")
        }
    }
    .menuStyle(.borderlessButton)
    .padding()
    .frame(width: 260)
}
