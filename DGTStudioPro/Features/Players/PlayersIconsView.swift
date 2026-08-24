import SwiftUI

/// The Players icons grid - the card and its two doors. The two Finder gestures, the frame
/// observation and the focus chrome are `IconGridView`'s; the pure grammar underneath them
/// (arrow stepping, band rectangles) is `IconGridSelection`'s. This file is only what makes the
/// grid the Players' one.
struct PlayersIconsView: View {

    // MARK: Stored Properties
    let players: [RankedPlayer]
    @Binding var selectedKeys: Set<PlayerStats.ID>
    let onShowInLibrary: (PlayerStats.ID) -> Void
    /// Double-click's door - the player's info window (17 Aug 2026; it opened the separate Matchup
    /// window until that merged into Get Info, 18 Aug 2026). Defaulted so previews stand.
    var onOpenInfo: (PlayerStats.ID) -> Void = { _ in }

    // MARK: Private Properties

    /// The card's read, not the grid's - see `LibraryIconsView`'s twin.
    @Environment(CollectionViewOptions.self) private var options

    // MARK: Body
    var body: some View {
        IconGridView(
            items: players,
            selection: $selectedKeys,
            space: "playersIconsGrid",
            collection: .players
        ) { player, isSelected, select in
            // Rank always rides the card - rank is a fact about the player, not the sort.
            PlayerCardView(
                stats: player.stats,
                isSelected: isSelected,
                onSelect: select,
                rank: player.rank,
                rating: player.rating,
                onOpen: { onOpenInfo(player.id) },
                // The Library card's `glyphWidth` arrangement with the monogram's own calibration:
                // 64 pt at the default 120, scaling linearly.
                monogramSide: options.iconSize(for: .players)
                    * (64 / CollectionViewOptions.defaultIconSize)
            )
            // Host-attached with the subject set (23 Aug 2026) - the Library grid's arrangement.
            // The menu's single-subject guard decides what renders: a card inside a
            // multi-selection yields no player verbs, the same answer the tables give, instead
            // of a menu describing one card while N are selected.
            .contextMenu {
                PlayerActionsMenu(
                    keys: subjectKeys(for: player),
                    onShowInLibrary: onShowInLibrary
                )
            }
        }
    }

    // MARK: Instance Methods

    /// Finder's rule, the Library grids' spelling, projected to the keys the menu speaks.
    private func subjectKeys(for player: RankedPlayer) -> [PlayerStats.ID] {
        IconGridSelection.subjects(for: player, in: players, selection: selectedKeys).map(\.id)
    }
}

// MARK: Previews

#Preview("With Players") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersIconsView(
        players: PreviewFixtures.rankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 720, height: 420)
    .environment(PreviewFixtures.viewOptions())
}

/// Wide enough for a full row - the 860 is load-bearing (column count derives from it), making
/// two rows. Preselected with *two* cards, the state single-select could never render.
#Preview("Wraps To Two Rows, Multi") {
    @Previewable @State var selection: Set<PlayerStats.ID> = Set(
        PreviewFixtures.deepRankedPlayers().prefix(2).map(\.id)
    )

    PlayersIconsView(
        players: PreviewFixtures.deepRankedPlayers(),
        selectedKeys: $selection,
        onShowInLibrary: { _ in }
    )
    .frame(width: 860, height: 420)
    .environment(PreviewFixtures.viewOptions())
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PlayerStats.ID> = []

    PlayersIconsView(players: [], selectedKeys: $selection, onShowInLibrary: { _ in })
        .frame(width: 720, height: 420)
        .environment(PreviewFixtures.viewOptions())
}
