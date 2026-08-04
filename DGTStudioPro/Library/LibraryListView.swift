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
    let onOpen: (PGN) -> Void
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
            // Never hideable: this cell carries the row identifier the
            // Library UITests addressed a game by (suite retired, D51′;
            // the identifier stays per the registry's bet). Hiding the
            // column wouldn't fail anything — it would make the element
            // cease to exist, and a future test would report "no such
            // game" about a Library that has it. Reordering and resizing
            // stay on; only visibility is contract-bearing, because an
            // identifier rides the cell wherever the column sits.
            TableColumn("White") { game in
                Text(game.whiteDisplayName)
                    .accessibilityIdentifier(AccessibilityID.gameRow(game.name))
            }
            .customizationID("white")
            .disabledCustomizationBehavior(.visibility)
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
            // operate on the whole set — Analyze enqueues in display
            // order via `LibraryDestination.requestAnalysis(ids:)`, and a
            // single id there routes through the single-game path (which
            // also surfaces the inspector).
            if ids.count == 1, let id = ids.first, let game = games.first(where: { $0.id == id }) {
                Button {
                    onOpen(game)
                } label: {
                    Label("Open in Board", systemImage: "checkerboard.rectangle")
                }
                // Single-selection only, beside Open and for its reason: Get
                // Info edits one subject's fields, and a multi-selection has
                // no single roster to show. A batch editor is a different
                // feature — the toolbar verbs are the ones that take a set.
                GetInfoMenuItem(
                    request: .game(game.persistentModelID),
                    identifier: AccessibilityID.getInfoMenuItem(Destination.library.rawValue)
                )
            }
            if !ids.isEmpty {
                // The toolbar's aggregate rule: checkmark only when the
                // whole set is analyzed.
                let selection = games.filter { ids.contains($0.id) }
                let analyzed = !selection.isEmpty && selection.allSatisfy(AnalysisGlyph.isAnalyzed)
                Button {
                    onAnalyzeIDs(ids)
                } label: {
                    // The counted plural keeps its verb: "Analyzed 3 Games"
                    // would read as a claim about what happened rather than a
                    // menu item you can click.
                    AnalysisLabel(
                        analyzed: analyzed,
                        title: ids.count > 1 ? "Analyze \(ids.count) Games" : nil
                    )
                }
                Button {
                    onExportIDs(ids)
                } label: {
                    Label(
                        ids.count > 1 ? "Export \(ids.count) PGNs" : "Export PGN",
                        systemImage: "square.and.arrow.up"
                    )
                }
                .accessibilityIdentifier(AccessibilityID.libraryExport)
                Divider()
                Button(role: .destructive) {
                    onDeleteIDs(ids)
                } label: {
                    Label(
                        ids.count > 1 ? "Delete \(ids.count) Games" : "Delete",
                        systemImage: "trash"
                    )
                }
            }
        } primaryAction: { ids in
            // Fires on row double-click *and* on Return when a row is
            // focused — both routes converge here so we don't need a
            // separate `.onSubmit` or key-press handler.
            if let id = ids.first, let game = games.first(where: { $0.id == id }) {
                onOpen(game)
            }
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
