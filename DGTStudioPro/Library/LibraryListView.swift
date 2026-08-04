//
//  LibraryListView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/04/2026.
//

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

    /// Which columns are shown, in what order, at what width — the state
    /// behind the header's right-click menu.
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

    var body: some View {
        Table(games, selection: $selectedPGNs, columnCustomization: $columnCustomization) {
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
            TableColumn("#") { game in
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
            // It was pinned visible until then, on the reasoning that hiding
            // the column would not *fail* anything but would make the element
            // cease to exist, so a future suite would report "no such game"
            // about a Library that has it. That was sound while a suite
            // existed. D51′ deleted the target, and what survived was a live
            // restriction on the app paid for a consumer that does not — the
            // same shape as a preview witnessing an arrangement the app has
            // retired, and it surfaced the way those do: someone tried to use
            // the thing and found it greyed out.
            //
            // The registry's own bet (see `AccessibilityID`'s header) is that
            // identifiers are worth *keeping* against a future suite. Keeping
            // strings in a file costs nothing. Pinning a column is a different
            // trade, and D51′ already ruled on that class: the suite's costs
            // outweighed its protection. If a suite returns, "unhide the White
            // column" is a line in its setup, not a permanent constraint here.
            //
            // Not relocated to another cell, and the reason is worth stating
            // because it was the obvious next move: **every** column is
            // hideable now, so no cell can be a guaranteed address. Moving the
            // identifier to `#` would trade one hideable host for another, and
            // that one renders an em dash for every game imported before D58′.
            TableColumn("White") { game in
                Text(game.whiteDisplayName)
                    .accessibilityIdentifier(AccessibilityID.gameRow(game.name))
            }
            .customizationID("white")
            TableColumn("Black") { Text($0.blackDisplayName) }
                .customizationID("black")
            TableColumn("Result") { game in
                Text(game.result.rawValue).foregroundStyle(.secondary)
            }
            .width(60)
            .customizationID("result")
            // Code only, not the name: at column width the family alone
            // truncates to "French Defe…", and the inspector's Opening
            // section is one click away with all three rows. An
            // unclassified game shows nothing rather than the inspector's
            // em dash — a table cell is already an empty-when-absent
            // surface, and a column of dashes is noise.
            //
            // Read through `opening`, not off `ecoCode` directly: that
            // accessor is where the both-or-neither invariant is checked,
            // and a row carrying a code without a family is exactly the
            // shape a second writer would leave behind. Reaching past it
            // here would make this the one surface that prints a code the
            // rest of the app calls unclassified — which is the failure the
            // invariant was written to surface, defeated by the reader.
            TableColumn("ECO") { game in
                Text(game.opening?.code ?? "").foregroundStyle(.secondary)
            }
            .width(min: 44, ideal: 52)
            .customizationID("eco")
            TableColumn("Event") { Text($0.event).lineLimit(1) }
                .customizationID("event")
            TableColumn("Date") { game in
                Text(game.displayDate).foregroundStyle(.secondary)
            }
            .width(100)
            .customizationID("date")
            TableColumn("Round") { game in
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

    LibraryListView(
        games: listPreviewGames(),
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in }
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    // Never `.standard`: the table's column layout is `@AppStorage` now, so a
    // canvas on the real suite would render whatever columns I last hid in the
    // app and read as a broken preview.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []

    LibraryListView(
        games: [],
        selectedPGNs: $selection,
        onOpen: { _ in },
        onAnalyzeIDs: { _ in },
        onExportIDs: { _ in },
        onDeleteIDs: { _ in }
    )
    .frame(width: 720, height: 360)
    .modelContainer(for: PGN.self, inMemory: true)
    // Never `.standard`: the table's column layout is `@AppStorage` now, so a
    // canvas on the real suite would render whatever columns I last hid in the
    // app and read as a broken preview.
    .defaultAppStorage(UserDefaults(suiteName: "preview")!)
}
