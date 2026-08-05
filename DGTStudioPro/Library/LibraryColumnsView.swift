import Foundation
import SwiftData
import SwiftUI

/// The Finder-column shape (2 Aug 2026 redesign): a flat list of games in
/// the first column, and the rest of the pane filled by the selected game's
/// detail — preview board on top, a Finder-style facts block beneath it.
///
/// This replaces the grouped browser (Event / Player / Year buckets driving
/// a card grid). The grouping was a second filtering surface in a
/// destination that already has one — smart tags own "show me a slice of
/// the Library" — so the columns mode's job is now inspection density, not
/// bucketing. `LibraryGroupingDimension`, `LibraryGroup` and the three
/// grouping folds were deleted with it; re-adding grouping means finding a
/// question the tags can't answer, not reverting this file.
///
/// The facts block renders the Seven Tag Roster through `RosterSummary`'s
/// subscript — the single place the display rules live (D22′) — and is
/// driven from `SevenTagRoster.allCases`, so this pane can't quietly lose a
/// tag any more than the inspectors' section can. `SevenTagRosterSection`
/// stays the *inspectors'* renderer; what is shared here is the formatting,
/// which is the half that must not fork.
internal struct LibraryColumnsView: View {

    // MARK: Stored Properties
    internal let games: [PGN]
    @Binding internal var selectedPGNs: Set<PGN.ID>
    internal let boardStyle: BoardStyle
    /// Takes the set since D56′. Deliberately **not** adapted with a
    /// `forEach` the way `onAnalyze` and friends are below: those fan out to a
    /// per-game door, while Open's door owns the count threshold, and a host
    /// that called it N times would walk straight past the guard.
    internal let onOpen: ([PGN]) -> Void
    internal let onAnalyze: (PGN) -> Void
    internal let onExport: (PGN) -> Void
    internal let onDelete: (PGN) -> Void

    /// Shared with list mode through `LibraryDestination` (5 Aug 2026), which
    /// is what makes a sort made in one mode survive the switch to the other.
    /// Same binding, same comparator array — deliberately not a second piece of
    /// state that would have to be kept in step.
    @Binding var sortOrder: [KeyPathComparator<PGN>]

    /// "No value to show" for the derived rows — the meaning
    /// `OpeningSection`'s em-dash carries, deliberately restated per surface
    /// (its own comment makes the same call beside `SevenTagRosterSection`'s).
    /// The roster rows never need it: `RosterSummary` speaks PGN's own `?`.
    private static let noValue = RosterSummary.displayUnknown

    // MARK: Computed Properties

    /// The single selected game, or nil when the selection is empty *or*
    /// multiple. The detail pane details one thing; multi-selection gets a
    /// counting placeholder rather than arbitrarily previewing `first` —
    /// the gallery's no-fallback rationale: never preview a game the user
    /// didn't pick.
    private var selectedGame: PGN? {
        guard selectedPGNs.count == 1, let id = selectedPGNs.first else { return nil }
        return games.first { $0.id == id }
    }

    // MARK: Body
    internal var body: some View {
        HSplitView {
            // 160/200/300, down from 220/260/340. A one-line row that
            // truncates in the middle needs far less width than the two-line
            // row that had to fit a date and a result side by side, and the
            // floor is the number that mattered: columns is the one mode
            // whose minimum is real (`HSplitView` sizes to content), so 60pt
            // off the floor is 60pt the sidebar and inspector stop competing
            // for. Belt and braces with the inspector suppression — that
            // change alone should clear the overflow; this makes the mode
            // survivable at window widths where it previously could not fit
            // at all.
            // `.layoutPriority(1)` is the floor's enforcement, not decoration.
            // `HSplitView` honours a child's `minWidth` only while the other
            // child isn't demanding more than what's left — and selecting a
            // game swaps a `ContentUnavailableView` for the facts block, whose
            // intrinsic width demand is larger. Without a priority the split
            // resolved that conflict by squeezing this pane past 160 (4 Aug,
            // observed). Priority makes the list's width non-negotiable and
            // pushes the compression onto the detail, which can take it: its
            // content wraps, where a truncated name does not degrade, it just
            // stops being readable.
            gameList
                .frame(minWidth: 160, idealWidth: 200, maxWidth: 300, maxHeight: .infinity)
                .layoutPriority(1)

            detail
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Instance Methods

    /// The empty arm is unreachable in production — `LibraryDestination`
    /// gates on `filteredGames.isEmpty` before the mode views are built —
    /// but previews construct this view directly, and an empty `List` with
    /// a selection binding renders as a bare void (the
    /// `PlayersColumnsView` precedent: both empty states have to hold).
    @ViewBuilder
    private var gameList: some View {
        if games.isEmpty {
            VStack {
                Spacer()
                Text("No games")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            // A one-column `Table`, not a `List` (4 Aug 2026, Bera's call).
            //
            // **The header is a known, accepted cost.** Shipping SwiftUI on
            // macOS has no modifier to suppress a `Table` header — the
            // compact-size-class collapse that hides it is an iOS behaviour
            // macOS never enters, and `tableStyle` governs insets and row
            // backgrounds, not header visibility. So this browser carries a
            // column header Finder's does not, deliberately, in exchange for
            // sharing `LibraryListView`'s row and selection machinery instead
            // of maintaining a second one. Recorded rather than discovered: if
            // the header ever becomes intolerable the answer is to revert this
            // to a `List`, not to hunt for a modifier that doesn't exist.
            //
            // **No `columnCustomization` binding, and that is load-bearing.**
            // `LibraryListView` persists its layout under a `StorageKeys` key;
            // binding the same one here would let hiding a column over there
            // empty this view entirely. One column has nothing to customize,
            // so the omission costs nothing and closes the hazard by
            // construction.
            // Sortable since 5 Aug 2026, sharing the destination's comparator
            // with list mode. The header above was documented one screen up as
            // an *accepted cost* — shipping SwiftUI on macOS cannot suppress
            // it — so this is that cost turning into the feature: a header that
            // had to be there anyway now does something.
            //
            // One consequence worth naming: sorting here writes the same state
            // list mode reads, so a sort made in either mode survives the
            // switch to the other. What it cannot do is *show* a sort it did
            // not set — order by Rating in list mode, come back here, and this
            // header carries no direction chevron while the rows are in rating
            // order. Honest rather than ideal: a one-column table has nowhere
            // to display an ordering it does not own.
            Table(games, selection: $selectedPGNs, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { game in
                    row(for: game)
                }
                // The 160 is the same number the enclosing frame carries, and
                // it has to be stated twice for two different reasons — this
                // is not the twin-read-site pattern D25′ warns about. The
                // frame's floor governs the *pane* inside the `HSplitView`;
                // this governs the *column* inside the table, which `Table`
                // will otherwise let the user drag narrower than the pane,
                // truncating names in a browser whose only job is names.
                //
                // All three, not `min:` alone — the min-only spelling did not
                // hold the floor in practice (4 Aug, observed). `.infinity`
                // for max is what keeps the column filling the pane rather
                // than leaving dead space on the right at wide splits; the
                // pane's own 300 max is what actually caps it.
                .width(min: 160, ideal: 200, max: .infinity)
            }
            .tableStyle(.inset)
            // Selection-typed, the `LibraryListView` shape — which is the
            // other half of the reuse. The per-row `.contextMenu` this
            // replaced could only ever act on one game; this one inherits
            // ⌘/⇧-click multi-select and hands the whole set to
            // `GameActionsMenu`, whose counted plurals were unreachable from
            // this view mode until now.
            .contextMenu(forSelectionType: PGN.ID.self) { ids in
                GameActionsMenu(
                    games: games.filter { ids.contains($0.id) },
                    onOpen: onOpen,
                    onAnalyze: { $0.forEach(onAnalyze) },
                    onExport: { $0.forEach(onExport) },
                    onDelete: { $0.forEach(onDelete) }
                )
            }
        }
    }

    /// **Finder's row: one icon, one name, one line** (3 Aug 2026).
    ///
    /// Was two lines carrying the date and the result as well. The argument
    /// for stripping them is the one the columns metaphor makes for itself:
    /// this is a *browser*, and every fact the row used to repeat is on the
    /// detail pane one column to the right, larger and in context. Finder
    /// does not put the modification date in the file list either — it puts
    /// it in the pane you get when you click.
    ///
    /// It buys width, which is not a side effect here. Columns mode was
    /// pushing the sidebar off screen because its floor exceeded the window
    /// (see `CollectionViewMode.ownsDetailPane`), and a row that no longer
    /// has to fit "21/07/2026" and "1/2-1/2" side by side is a row that can
    /// live in a narrower column.
    ///
    /// The icon is uniform, deliberately. Making it carry state — result, or
    /// analysis — would be a third encoding of facts the detail pane already
    /// states, and Finder's own list gets its plainness precisely from every
    /// row of a kind looking identical.
    private func row(for game: PGN) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .foregroundStyle(.tint)
                .imageScale(.medium)
            Text(game.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 1)
        // The menu moved to the `Table` as a selection-typed one — see
        // `gameList`. A per-row `.contextMenu` inside a `Table` cell would
        // shadow it and act on one game regardless of what is selected.
    }

    @ViewBuilder
    private var detail: some View {
        if let game = selectedGame {
            gameDetail(game)
        } else if selectedPGNs.count > 1 {
            ContentUnavailableView(
                "\(selectedPGNs.count) Games Selected",
                systemImage: "square.on.square",
                description: Text("The toolbar's Analyze, Export and Delete act on the whole selection.")
            )
        } else {
            ContentUnavailableView(
                "No Game Selected",
                systemImage: "square.dashed",
                description: Text("Select a game in the list to see its details.")
            )
        }
    }

    /// Raw PGN above, facts below (3 Aug 2026).
    ///
    /// **The board is gone, and it was the cause of the squeeze.** This used
    /// to render `LibraryGamePreviewView` whole — header, board, async replay
    /// — and `BoardView` is `aspectRatio(1, .fit)` over a `GeometryReader`,
    /// so in a tall window it demands a width equal to its height. That is
    /// not a view taking the space it is given; it is a view *asking* for
    /// width, and in an `HSplitView` the ask wins. Selecting a game visibly
    /// stole width from the list column beside it, which is the same
    /// mechanism that pushed the sidebar off screen, arriving from a
    /// different direction.
    ///
    /// Text has no such appetite: it wraps. So the detail pane now shows what
    /// the file will actually say, at a size worth reading, and reflows into
    /// whatever width is left instead of bidding for more.
    ///
    /// `PGN.pgnText` is the same accessor the inspector reads — byte-identical
    /// to what Export writes (D24′). Not a second rendering of the model: a
    /// detail pane that formatted its own tag block would be a third PGN
    /// shape in the app, free to drift from the reference files that pin it.
    ///
    /// `boardStyle` is still taken as a parameter and no longer read here.
    /// Left in place rather than threaded out: `LibraryDestination` passes it
    /// to every mode view uniformly, and removing it from one of four is a
    /// signature change that buys nothing while making the call sites differ.
    ///
    /// The serialization runs per body pass while a game is selected — the
    /// inspector's PGN-section cost without its collapse gate. Accepted and
    /// carried on the known-costs census (4 Aug 2026): one game, not a walk,
    /// and columns mode re-renders on selection, not on keystrokes.
    private func gameDetail(_ game: PGN) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(game.pgnText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            factsAndActions(game)
        }
    }

    private func factsAndActions(_ game: PGN) -> some View {
        let roster = RosterSummary(game)
        return VStack(spacing: 16) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                ForEach(SevenTagRoster.allCases, id: \.self) { tag in
                    factRow(tag.rawValue, roster[tag])
                }
                factRow("Opening", game.opening.map { "\($0.code) · \($0.fullName)" } ?? Self.noValue)
                factRow("Moves", game.moves.isEmpty ? Self.noValue : "\((game.moves.count + 1) / 2)")
                factRow("Time Control", game.timeControl ?? Self.noValue)
                factRow("Board", game.board ?? Self.noValue)
            }
            .frame(maxWidth: 420)

            HStack(spacing: 12) {
                Button {
                    // Singular by construction: the detail pane renders only
                    // for a count-of-one selection, so this button never has a
                    // set to open even though the door now takes one.
                    onOpen([game])
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(.borderedProminent)
                .help("Open this game in its own window")

                Button {
                    onAnalyze(game)
                } label: {
                    AnalysisLabel(analyzed: AnalysisGlyph.isAnalyzed(game))
                }
                .help("Analyze this game with Stockfish")
            }
        }
        .padding(20)
    }

    /// Finder's info-row shape: the label column right-aligned against the
    /// values. Values truncate in the middle — the long ones are serials
    /// and site names, whose ends carry the information.
    private func factRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    }
}

// MARK: Previews
private func columnsPreviewGames() -> [PGN] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy.MM.dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    return [
        // Carries moves, a time control and a board so every derived facts
        // row has a value — the fully-populated branch.
        PGN(event: "World Championship", site: "Dubai",
            date: formatter.date(from: "2021.12.10"),
            round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian",
            moves: ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"],
            result: .whiteWins,
            timeControl: "40/7200"),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee",
            date: formatter.date(from: "2024.01.20"),
            round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger",
            date: formatter.date(from: "2023.06.03"),
            round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
        // Undated and moveless: the date placeholder in the row, and the
        // em-dash branch of every derived facts row at once.
        PGN(event: "Norway Chess", site: "Stavanger",
            date: nil,
            round: 5,
            white: "Carlsen, Magnus", black: "Firouzja, Alireza", result: .whiteWins)
    ]
}

#Preview("Detail") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    let games = columnsPreviewGames()

    LibraryColumnsView(
        games: games,
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .onAppear {
        if let id = games.first?.id { selection = [id] }
    }
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Multi-Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    let games = columnsPreviewGames()

    LibraryColumnsView(
        games: games,
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .onAppear {
        selection = Set(games.prefix(2).map(\.id))
    }
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("No Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    LibraryColumnsView(
        games: columnsPreviewGames(),
        selectedPGNs: $selection,
        boardStyle: .rosewood,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    LibraryColumnsView(
        games: [],
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in },
        sortOrder: $sort
    )
    .frame(width: 900, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
}
