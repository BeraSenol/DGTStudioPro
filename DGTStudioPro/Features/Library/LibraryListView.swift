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

    /// Which columns are shown and in what order — the state behind the
    /// header's right-click menu.
    ///
    /// **This said "and at what width" until 5 Aug 2026, and that was wrong.**
    /// `TableColumnCustomization` carries visibility and order;
    /// Apple's own forum answer on column widths is that there is "no way to
    /// listen for changes in the column widths when the user resizes and no way
    /// to set the size from code", and that width state restoration is not
    /// supported. So a resized column has never survived a relaunch here, and
    /// this comment claimed it did — a plausible sentence about a framework,
    /// written once and never checked, which is the species this project keeps
    /// cataloguing. Checkable in twenty seconds: resize a column, quit,
    /// relaunch.
    ///
    /// Left as a standing note rather than removed with the auto-fit feature it
    /// was found by: the fact is about SwiftUI, not about that feature, and it
    /// is the reason any future attempt at remembering a column width has to
    /// start somewhere other than this property.
    ///
    /// `@AppStorage` rather than D45′'s owning-type shape, and the difference
    /// is worth stating because D45′ argued the other way. That decision moved
    /// off `@AppStorage` because its value had **two** readers who had to
    /// agree (the header drew the chevron, the host gated the body); this one
    /// has exactly one — the `Table` it is bound to. What the property wrapper
    /// buys here is the thing a hand-constructed object had to be given by
    /// hand: `.defaultAppStorage(_:)` redirects it, so a seeded UI run reads
    /// the scratch suite instead of whatever columns I last hid.
    ///
    /// The customization IDs below are a **persistence contract**. They are
    /// stored verbatim, so renaming one silently resets that column to its
    /// shipped state — the `InspectorSection` raw-value situation, and the
    /// same remedy: hand-written, never derived from the title, because the
    /// title is what a reader would reach for and titles are editable prose.
    @AppStorage(StorageKeys.libraryColumns)
    private var columnCustomization = TableColumnCustomization<PGN>()

    /// Ambient, written once by `LibraryDestination` — the Analysis column's
    /// cells need it to tell "analyzed" from "on the engine right now", and a
    /// parameter for it would be a sixth argument every host has to thread.
    /// The argument is at the environment value's declaration.
    @Environment(\.analysisRunningGameID) private var runningAnalysisID

    /// Click a header once to sort ascending, twice to reverse — `Table`'s own
    /// behaviour, bound rather than built (5 Aug 2026).
    ///
    /// **A binding and not `@State`, which is the load-bearing half of this
    /// change.** Sorting here would reorder the rows on screen and nothing
    /// else, and three things downstream read *display order* rather than the
    /// screen: D24′ numbers exported filenames from it, the analysis queue
    /// crunches top-to-bottom as shown, and D56′ makes it tab order. Those all
    /// resolve through `LibraryDestination.gamesInDisplayOrder`, so the sort
    /// has to live where `filteredGames` can apply it — otherwise export
    /// silently numbers by one order while the reader is looking at another,
    /// which is a disagreement no test would catch and no screen would show.
    ///
    /// Deliberately **not** persisted, unlike `columnCustomization` one
    /// property up. A hidden column is a statement about what this reader
    /// cares about; a sort is a statement about the question being asked right
    /// now, and a Library that reopens sorted by Round because of something
    /// done last Tuesday is answering a question nobody is asking.
    ///
    /// Not persisting is what makes the default *load-bearing* rather than
    /// merely initial: every launch opens on `#` descending (5 Aug 2026), so
    /// that ordering is a property of the Library rather than of whatever was
    /// last clicked. The default and its consequences are argued at
    /// `LibraryDestination.sortOrder`, which owns the value.
    @Binding var sortOrder: [KeyPathComparator<PGN>]

    var body: some View {
        Table(games,
              selection: $selectedPGNs,
              sortOrder: $sortOrder,
              columnCustomization: $columnCustomization) {
            // D58′ — the ordinal the game's file carries on disk, leading the
            // table because that is where a filing number reads.
            //
            // Hideable, like every column in this table as of 5 Aug 2026 —
            // this comment drew a contrast with White until White stopped
            // being the exception. See its note below for why.
            //
            // Em dash for nil rather than an empty cell, which is the opposite
            // of the ECO column's call one screen down and deliberately so: an
            // absent ECO means "we could not name this opening", a fact about
            // the game that a blank states fine. An absent index means "this
            // game did not come from a numbered file", which is a fact about
            // the *column's* premise — and a blank there reads as a rendering
            // failure in a column of otherwise unbroken numbers.
            // `sortUsing:` rather than `value:` here and at every other
            // optional-valued column below: `value:` requires the sort value to
            // be `Comparable`, and `Optional` is not — `KeyPathComparator` has
            // the initializer that takes an optional key path instead. Both
            // forms produce a `KeyPathComparator<PGN>`, which is what lets them
            // mix in one table.
            TableColumn("#", sortUsing: KeyPathComparator(\PGN.libraryIndex)) { game in
                Text(game.libraryIndex.map(String.init) ?? RosterSummary.displayUnknown)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 34, ideal: 44, max: 64)
            .customizationID("index")

            // This cell carries the row identifier — `gameRow(name)`, the
            // address a test would reach a game by — and it is **hideable
            // anyway** as of 5 Aug 2026.
            //
            // Pinned visible until then so a future suite could not lose its
            // address. Sound while a suite existed; D51′ deleted it, leaving a
            // live restriction on the app paid for a consumer that does not
            // exist. Found the way those always are — someone tried to hide the
            // column and asked why it was greyed out.
            //
            // Keeping identifier strings in a file costs nothing and stands (see
            // `AccessibilityID`'s header). Pinning a control the user reaches for
            // is a different trade, and D51′ already ruled on that class.
            //
            // Not relocated to another cell, which was the obvious next move:
            // **every** column is hideable now, so no cell is a guaranteed
            // address. Moving the identifier to `#` would swap one hideable host
            // for another, and that one renders an em dash for every pre-D58′
            // game besides.
            //
            // Sorted on the **display** form, not the stored tag: the column
            // shows "Magnus Carlsen", and sorting by `[White "Carlsen, Magnus"]`
            // would order by a surname the cell does not print. Right for a
            // table, wrong for a filing system — a by-surname order would be a
            // *second* column, not a quiet swap of this key.
            TableColumn("White", value: \.whiteDisplayName) { game in
                Text(game.whiteDisplayName)
                    .accessibilityIdentifier(AccessibilityID.gameRow(game.name))
            }
            .customizationID("white")
            TableColumn("Black", value: \.blackDisplayName) { Text($0.blackDisplayName) }
                .customizationID("black")

            // 7 Aug 2026, by request — the analysis state per row, and clicking
            // it queues that game.
            //
            // **This is the tenth column, which is the ceiling.**
            // `TableColumnBuilder` is a result builder and result builders top
            // out at ten statements — a lesson already on this project's
            // build-diagnostics list, arrived at here from the other direction.
            // An eleventh column does not warn: it fails to type-check, and
            // `Table`'s diagnostics in that state are famously unhelpful. The
            // remedy when it happens is a `Group` around a subset, not deleting
            // a column to make room.
            //
            // **The only column with a control in it**, which is why it is
            // worth arguing rather than just adding. Every other cell here
            // renders a fact; this one renders a fact *and* the verb that
            // changes it. That is defensible exactly because the two are the
            // same thing to a reader: "not analyzed" and "analyze this" are one
            // thought, and making the state its own button is fewer moving
            // parts than a state column beside an action column.
            //
            // **Deliberately not sortable, unlike every other column here**, and
            // the reason is motion rather than difficulty. `filteredGames`
            // sorts once per render, so a table sorted on analysis state would
            // reshuffle every time a game finished — eighteen reshuffles during
            // an eighteen-game batch, each one moving the row you were about to
            // click. The token chips already answer "show me the unanalyzed
            // ones" without moving anything, which is the better tool for the
            // question a sort would be asked for.
            TableColumn("Analysis") { game in
                Button {
                    // The singular set, not `selectedPGNs`: clicking a row's
                    // button is a statement about *that* row. Routed through
                    // the same closure the context menu uses, so the count
                    // threshold and display-order resolution in
                    // `requestAnalysis(ids:)` apply identically.
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
                // table stops reading as a table. It also keeps the click from
                // being swallowed before the row's own selection handling.
                .buttonStyle(.borderless)
                // Live while analyzing rather than disabled: `AnalysisQueue`
                // skips an id already running, so a second click is a no-op
                // instead of a second pass — the argument at
                // `AnalysisGlyph.actionTitle`, made good here.
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
            // Code only, not the name: at column width the family truncates to
            // "French Defe…", and the inspector's Opening section is one click
            // away with all three rows. An unclassified game shows nothing
            // rather than an em dash — a column of dashes is noise.
            //
            // Read *and* sorted through `opening`, never off `ecoCode` directly.
            // That accessor is where the both-or-neither invariant is checked,
            // so reaching past it would make this the one surface printing a
            // code the rest of the app calls unclassified — the invariant
            // defeated from the reader's side, whether through the cell or
            // through the comparator.
            //
            // Named cost: `opening` rehydrates an `ECOOpening` per access, and
            // the sort is applied inside `filteredGames`, which *is* the
            // per-render fold — so a reader sitting on this column pays the
            // rehydrates every render, not once per click. Invisible at
            // personal-library scale, on the known-costs census, and still not a
            // reason to reach past the accessor: that trades a real invariant
            // for a hypothetical measurement.
            TableColumn("ECO", sortUsing: KeyPathComparator(\PGN.opening?.code)) { game in
                Text(game.opening?.code ?? "").foregroundStyle(.secondary)
            }
            .width(min: 44, ideal: 52)
            .customizationID("eco")
            // D19′/D34′'s other half. The table has shown the *opening* side of
            // classification since M4 and not the mate side, which was an
            // asymmetry rather than a decision — the two are classified
            // together, stamped together and cleared together.
            //
            // **Em dash for "no motif", where ECO one column up shows nothing**,
            // and the divergence is the right way round: D55′ made the em dash
            // the house glyph for every absent display value, so this is the
            // rule and ECO is the documented exception (it argues a column of
            // dashes is noise where a blank states the fact fine). Worth naming
            // because two adjacent classification columns disagreeing looks
            // careless until you read both.
            //
            // Sorted on the stored `rawValue`, not `displayName`: the two are
            // 1:1 so no divergence is possible, and the stored side needs no
            // rehydrate. Ascending puts un-mated games first; a second click
            // groups the motifs at the top, which is the reading anyone
            // clicking this column wants.
            TableColumn("Checkmate Type", sortUsing: KeyPathComparator(\PGN.specialCheckmate?.rawValue)) { game in
                Text(game.specialCheckmate?.displayName ?? RosterSummary.displayUnknown)
                    .foregroundStyle(.secondary)
            }
            // Wide enough for the header, which is now longer than anything
            // it labels — "Checkmate Type" against "Back Rank". The
            // customization ID stays `"mate"`: it is stored state and
            // deliberately not derived from the title, so the rename cannot
            // reset a reader's column layout.
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
            // `ids` is the set the menu acts on: the full selection when a
            // selected row is right-clicked, otherwise just that row. Open
            // stays single-game (one window per game); Analyze and Delete
            // operate on the whole set — Analyze enqueues in display order via
            // `LibraryDestination.requestAnalysis(ids:)`, and a single id
            // there routes through the single-game path (which also surfaces
            // the inspector).
            //
            // **Resolved to models here rather than passed as ids**, which is
            // the adaptation `GameActionsMenu` documents each host owing it.
            // The filter is not just a lookup: it is what puts the games in
            // *display* order, which a `Set<PGN.ID>` cannot carry and which is
            // the order the enqueue above depends on. The closures convert
            // back at the boundary because this view's owners speak in ids.
            //
            // This host was the menu's model — its counted plurals and its
            // single-selection guard are the shape the shared type was built
            // around — so it is the last of the three to adopt and the one
            // whose behaviour should be unchanged by having done so.
            GameActionsMenu(
                games: games.filter { ids.contains($0.id) },
                onOpen: onOpen,
                onAnalyze: { onAnalyzeIDs(Set($0.map(\.id))) },
                onExport: { onExportIDs(Set($0.map(\.id))) },
                onDelete: { onDeleteIDs(Set($0.map(\.id))) }
            )
        } primaryAction: { ids in
            // Fires on row double-click *and* on Return when a row is
            // focused — both routes converge here so we don't need a
            // separate `.onSubmit` or key-press handler.
            //
            // **Opens the whole set since D56′, and this is where the old
            // arbitrary pick lived.** It read `ids.first`, which over a
            // multi-selection meant "some row, in `Set` order" — a game wearing
            // another game's face, the exact defect `selectedPGN(in:)` refuses
            // one file over. `primaryAction` hands over the selection when a
            // *selected* row is double-clicked and the single row otherwise, so
            // Finder's rule arrives for free and the menu's ⌘O and this gesture
            // now answer the same question the same way.
            //
            // Resolved through `games` rather than passed as ids: that filter
            // is what puts them in display order, which is tab order.
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
