import SwiftUI

/// The Players context menu, once — `GameActionsMenu`'s twin. **Single-subject** where the
/// Library's counts: both verbs describe one player.
struct PlayerActionsMenu: View {

    // MARK: Stored Properties

    /// `Player.normalizedName` — the key every Players surface addresses rows by.
    let key: PlayerStats.ID

    /// Optional because navigation is the *host's* capability: card hosts without a Library route
    /// pass nothing and the item does not render (an affordance that cannot act should not exist).
    var onShowInLibrary: ((PlayerStats.ID) -> Void)? = nil

    // MARK: Body
    var body: some View {
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
            // Inside the optional-closure guard on purpose: a host with no route must not advertise the
            // key either — a shortcut outliving its affordance is the D40′ shape wearing a key equivalent.
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .accessibilityIdentifier(AccessibilityID.contextShowInLibrary)
        }
    }
}

// MARK: Previews

/// Inside a `Menu` (a canvas has no right-click). Both arities — the optional closure is the
/// only thing this type decides.
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
