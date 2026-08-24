import SwiftUI

/// The Players context menu, once - `GameActionsMenu`'s twin. Takes the same subject set every
/// host resolves (the whole selection when a selected row or card is right-clicked, else the one
/// under the pointer) and renders its verbs **only for a single subject**: both describe one
/// player, and no Players verb takes a set. A multi-selection therefore gets no items - honest,
/// and the same answer in all four view modes.
///
/// It took one `key` until 23 Aug 2026, which forced every plural host to pick: the list and
/// columns read `keys.first` of the selection `Set`, so a multi-selection's menu named whichever
/// member the set happened to order first - Get Info for "some player". The arity guard lives
/// here rather than at the four call sites so a fifth host cannot re-open the question.
struct PlayerActionsMenu: View {

    // MARK: Stored Properties

    /// `Player.normalizedName`s - the key every Players surface addresses rows by. Resolved by
    /// the host through its own selection rule (`IconGridSelection.subjects` for the grids,
    /// `.contextMenu(forSelectionType:)` for the tables).
    let keys: [PlayerStats.ID]

    /// Optional because navigation is the *host's* capability: card hosts without a Library route
    /// pass nothing and the item does not render (an affordance that cannot act should not exist).
    var onShowInLibrary: ((PlayerStats.ID) -> Void)? = nil

    // MARK: Body
    var body: some View {
        if keys.count == 1, let key = keys.first {
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
                // key either - a shortcut outliving its affordance is the shape wearing a key equivalent.
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .accessibilityIdentifier(AccessibilityID.contextShowInLibrary)
            }
        }
        // No plural arm, deliberately: Get Info resolves one subject and Show in Library filters
        // on one key. If a batch verb ever arrives, it lands here and every mode gets it at once.
    }
}

// MARK: Previews

/// Inside a `Menu` (a canvas has no right-click). Three arities - the optional closure and the
/// single-subject guard are the only things this type decides, so the multi case renders empty
/// on purpose (macOS suppresses an itemless context menu; a bare `Menu` shows the void).
#Preview("Arities and Navigation") {
    VStack(alignment: .leading, spacing: 16) {
        Menu("One Player, With Navigation") {
            PlayerActionsMenu(keys: ["carlsen, magnus"], onShowInLibrary: { _ in })
        }
        Menu("One Player, Without") {
            PlayerActionsMenu(keys: ["carlsen, magnus"])
        }
        Menu("Two Players (No Items)") {
            PlayerActionsMenu(
                keys: ["carlsen, magnus", "nepomniachtchi, ian"],
                onShowInLibrary: { _ in }
            )
        }
    }
    .menuStyle(.borderlessButton)
    .padding()
    .frame(width: 260)
}
