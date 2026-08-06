import SwiftData
import SwiftUI

internal struct LibraryListView: View {
    let games: [PGN]
    @Binding var selectedPGNs: Set<PGN.ID>
    /// Takes the set since D56′, like every other action here.
    let onOpen: ([PGN]) -> Void
    let onAnalyzeIDs: (Set<PGN.ID>) -> Void
    let onExportIDs: (Set<PGN.ID>) -> Void
    let onDeleteIDs: (Set<PGN.ID>) -> Void

    /// Which columns are shown and in what order — the header's right-click
    /// menu.
    ///
    /// **Visibility and order only. `TableColumnCustomization` cannot carry
    /// width**: SwiftUI offers no way to observe a resize or set a size from
    /// code, and no width restoration. Any future attempt at remembering a
    /// column width has to start somewhere other than this property.
    ///
    /// `@AppStorage` rather than D45′'s owning-type shape, which argued the
    /// other way — that value had two readers who had to agree, this one has
    /// exactly one. What the wrapper buys is `.defaultAppStorage(_:)`
    /// redirection, so a seeded run reads a scratch suite rather than whatever
    /// columns were last hidden.
    ///
    /// The customization IDs below are a **persistence contract**: stored
    /// verbatim, so renaming one silently resets that column. Hand-written,
    /// never derived from the title, since titles are editable prose.
    @AppStorage(StorageKeys.libraryColumns)
    private var columnCustomization = TableColumnCustomization<PGN>()

    /// Ambient, written once by `LibraryDestination` — the Analysis column
    /// needs it to tell "analyzed" from "on the engine right now". Argued at
    /// the environment value's declaration.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    /// Click a header once to sort ascending, twice to reverse.
    ///
    /// **A binding, not `@State`.** Three things downstream read *display
    /// order* rather than the screen: D24′ numbers exported filenames from it,
    /// the queue crunches top-to-bottom as shown, and D56′ makes it tab order.
    /// All resolve through `gamesInDisplayOrder`, so the sort has to live where
    /// `filteredGames` can apply it — otherwise export numbers by one order
    /// while the reader looks at another, a disagreement no test would catch.
    ///
    /// **Not persisted**, unlike `columnCustomization`: a hidden column says
    /// what this reader cares about, a sort says what is being asked right now.
    /// That makes the `#`-descending default load-bearing rather than initial —
    /// argued at `LibraryDestination.sortOrder`, which owns the value.
    @Binding var sortOrder: [KeyPathComparator<PGN>]

    var body: some View {
        Table(games,
              selection: $selectedPGNs,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            // D58′ — the ordinal the game's file carries on disk, leading the
            // table because that is where a filing number reads.
            //
            // Em dash for nil, the opposite of ECO's blank one screen down and
            // deliberately: an absent ECO means "we could not name this
            // opening", which a blank states fine, while an absent index means
            // the game came from no numbered file — and a blank there reads as
            // a rendering failure in a column of otherwise unbroken numbers.
            //
            // `sortUsing:` rather than `value:` here and at every other
            // optional-valued column: `value:` needs the sort value to be
            // `Comparable` and `Optional` is not. Both forms produce a
            // `KeyPathComparator<PGN>`, which is what lets them mix.
            TableColumn("#", sortUsing: KeyPathComparator(\PGN.libraryIndex)) { game in
                Text(game.libraryIndex.map(String.init) ?? RosterSummary.displayUnknown)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 34, ideal: 44, max: 64)
            .customizationID("index")

            // Carries the row identifier `gameRow(name)`, and is **hideable
            // anyway** — D51′ deleted the suite that pinning protected, and no
            // cell is a guaranteed address now. Not relocated to `#`, which
            // would swap one hideable host for another and renders an em dash
            // for every pre-D58′ game besides.
            //
            // Sorted on the **display** form, not the stored tag: the column
            // shows "Magnus Carlsen", and sorting by `[White "Carlsen, Magnus"]`
            // would order by a surname the cell does not print. A by-surname
            // order would be a *second* column, not a quiet swap of this key.
            TableColumn("White", value: \.whiteDisplayName) { game in
                Text(game.whiteDisplayName)
                    .accessibilityIdentifier(AccessibilityID.gameRow(game.name))
            }
            .customizationID("white")
            TableColumn("Black", value: \.blackDisplayName) { Text($0.blackDisplayName) }
                .customizationID("black")

            // The analysis state per row; clicking queues that game.
            //
            // **The tenth column, which is the ceiling** — `TableColumnBuilder`
            // is a result builder and those top out at ten. An eleventh does
            // not warn, it fails to type-check with unhelpful diagnostics; the
            // remedy is a `Group` around a subset, not deleting a column.
            //
            // **The only column with a control in it.** Defensible because the
            // fact and the verb are one thought to a reader: "not analyzed" and
            // "analyze this" are the same cell, which is fewer moving parts
            // than a state column beside an action column.
            //
            // **Deliberately not sortable**, unlike every other column here.
            // `filteredGames` sorts once per render, so sorting on analysis
            // state would reshuffle the table each time a game finished, moving
            // the row you were about to click. The Not Analyzed chip answers
            // the same question without moving anything.
            TableColumn("Analysis") { game in
                Button {
                    // The singular set, not `selectedPGNs`: clicking a row's
                    // button is a statement about *that* row. Same closure the
                    // context menu uses, so the count threshold and
                    // display-order resolution apply identically.
                    onAnalyzeIDs([game.id])
                } label: {
                    AnalysisLabel(
                        state: AnalysisGlyph.state(
                            of: [game],
                            runningID: runningAnalysisID
                        )
                    )
                }
                // `.borderless`, or every row grows a bordered button and the
                // table stops reading as a table.
                .buttonStyle(.borderless)
                // Live while analyzing rather than disabled: `enqueue` skips an
                // id already running, so a second click is a no-op.
                .help("Analyze this game with Stockfish")
            }
            .width(min: 96, ideal: 116, max: 160)
            .customizationID("analysis")
            // The raw value, so the order is the PGN vocabulary's own — 0-1,
            // 1-0, 1/2-1/2, * — rather than `GameResult`'s declaration order.
            // Neither is meaningful as a ranking; this one at least matches
            // what the cell prints, which is the only thing a reader can check.
            TableColumn("Result", value: \.result.rawValue) { game in
                Text(game.result.rawValue).foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("result")
            // Code only: at column width the family truncates to "French
            // Defe…", and the inspector's Opening section has all three rows.
            // Unclassified shows nothing rather than an em dash — a column of
            // dashes is noise.
            //
            // Read *and* sorted through `opening`, never off `ecoCode`: that
            // accessor checks the both-or-neither invariant, so reaching past
            // it would make this the one surface printing a code the rest of
            // the app calls unclassified.
            //
            // Named cost: `opening` rehydrates per access and the sort runs
            // inside `filteredGames`, the per-render fold — so this column pays
            // rehydrates every render. On the known-costs census, and not a
            // reason to reach past the accessor.
            TableColumn("ECO", sortUsing: KeyPathComparator(\PGN.opening?.code)) { game in
                Text(game.opening?.code ?? "").foregroundStyle(.secondary)
            }
            .width(min: 44, ideal: 52)
            .customizationID("eco")
            // D19′/D34′'s other half — the two are classified, stamped and
            // cleared together, so showing only the opening side was an
            // asymmetry rather than a decision.
            //
            // **Em dash for "no motif", where ECO one column up shows nothing.**
            // D55′ made the em dash the house glyph for an absent display
            // value, so this is the rule and ECO is the documented exception.
            // Named because two adjacent classification columns disagreeing
            // looks careless until you read both.
            //
            // Sorted on the stored `rawValue`, not `displayName`: 1:1, so no
            // divergence is possible and no rehydrate is needed.
            TableColumn("Checkmate Type", sortUsing: KeyPathComparator(\PGN.specialCheckmate?.rawValue)) { game in
                Text(game.specialCheckmate?.displayName ?? RosterSummary.displayUnknown)
                    .foregroundStyle(.secondary)
            }
            // Wide enough for the header, longer than anything it labels. The
            // customization ID stays `"mate"` — stored state, deliberately not
            // derived from the title, so a rename cannot reset a column layout.
            .width(min: 96, ideal: 110)
            .customizationID("mate")
            TableColumn("Event", value: \.event) { Text($0.event).lineLimit(1) }
                .customizationID("event")
            // `effectiveDate` (date ?? importedAt), which is the app's one
            // ordering rule for a game with no date (D10′) and the same key
            // `chronologicalOrder` folds by — so this column agrees with every
            // pure fold rather than inventing a second answer.
            //
            // Display and sort deliberately diverge for an undated game: the
            // cell prints an em dash while the row sorts by its import time.
            // The alternative is sorting on `date` and letting every undated
            // game clump at one end, which looks like a bug and is a worse lie
            // than the dash — the game *does* have a position in time, and it
            // is the one the rest of the app already uses.
            TableColumn("Date", value: \.effectiveDate) { game in
                Text(game.displayDate).foregroundStyle(.secondary)
            }
            .width(100)
            .customizationID("date")
            TableColumn("Round", sortUsing: KeyPathComparator(\PGN.round)) { game in
                Text(game.displayRound).foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("round")
        }
        .accessibilityIdentifier(AccessibilityID.libraryGamesTable)
        .contextMenu(forSelectionType: PGN.ID.self) { ids in
            // `ids` is the full selection when a selected row is right-clicked,
            // otherwise just that row.
            //
            // **Resolved to models here rather than passed as ids.** The filter
            // is not a lookup — it is what puts the games in *display* order,
            // which a `Set<PGN.ID>` cannot carry and which the enqueue depends
            // on. The closures convert back at the boundary because this view's
            // owners speak in ids.
            GameActionsMenu(
                games: games.filter { ids.contains($0.id) },
                onOpen: onOpen,
                onAnalyze: { onAnalyzeIDs(Set($0.map(\.id))) },
                onExport: { onExportIDs(Set($0.map(\.id))) },
                onDelete: { onDeleteIDs(Set($0.map(\.id))) }
            )
        } primaryAction: { ids in
            // Fires on row double-click *and* on Return, so no separate
            // `.onSubmit` is needed.
            //
            // **Opens the whole set (D56′).** This read `ids.first` once, which
            // over a multi-selection meant "some row, in `Set` order" — a game
            // wearing another's face. `primaryAction` hands over the selection
            // when a *selected* row is double-clicked and the single row
            // otherwise, so Finder's rule arrives for free.
            //
            // Resolved through `games` rather than ids: that filter is what
            // puts them in display order, which is tab order.
            onOpen(games.filter { ids.contains($0.id) })
        }
    }
}

// MARK: Previews
private func listPreviewGames() -> [PGN] {
    [
        PGN(event: "World Championship", site: "Dubai", round: 11,
            white: "Carlsen, Magnus", black: "Nepomniachtchi, Ian", result: .whiteWins),
        PGN(event: "Tata Steel Masters", site: "Wijk aan Zee", round: 7,
            white: "Giri, Anish", black: "Caruana, Fabiano", result: .draw),
        PGN(event: "Norway Chess", site: "Stavanger", round: 3,
            white: "Firouzja, Alireza", black: "Ding, Liren", result: .blackWins),
        PGN(event: "Candidates Tournament", site: "Madrid", round: 14,
            white: "Nepomniachtchi, Ian", black: "Ding, Liren", result: .ongoing)
    ]
}

#Preview("With Games") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    LibraryListView(
        games: listPreviewGames(),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    // Never `.standard`: the table's column layout is `@AppStorage` now, so a
    // canvas on the real suite would render whatever columns I last hid in the
    // app and read as a broken preview.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

// Sorted rather than empty, and it is the branch the other two previews cannot
// reach: `sortOrder` non-empty is what draws the header's direction chevron, so
// this is the only canvas that shows a sorted table looking sorted. Round is
// the column chosen on purpose — it is optional-valued, so this also renders
// the `sortUsing:` arm rather than the `value:` one.
#Preview("Sorted by Round") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort: [KeyPathComparator<PGN>] =
        [KeyPathComparator(\PGN.round)]

    LibraryListView(
        games: listPreviewGames().sorted(using: sort),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []
    @Previewable @State var sort = LibraryDestination.defaultSortOrder

    LibraryListView(
        games: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in },
        sortOrder: $sort
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    // Never `.standard`: the table's column layout is `@AppStorage` now, so a
    // canvas on the real suite would render whatever columns I last hid in the
    // app and read as a broken preview.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
