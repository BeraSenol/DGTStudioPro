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

    var body: some View {
        Table(games, selection: $selectedPGNs) {
            TableColumn("White") { game in
                Text(game.whiteDisplayName)
                    .accessibilityIdentifier(AccessibilityID.gameRow(game.name))
            }
            TableColumn("Black") { Text($0.blackDisplayName) }
            TableColumn("Result") { game in
                Text(game.result.rawValue).foregroundStyle(.secondary)
            }
            .width(60)
            // Code only, not the name: at column width the family alone
            // truncates to "French Defe…", and the inspector's Opening
            // section is one click away with all three rows. An
            // unclassified game shows nothing rather than the inspector's
            // em dash — a table cell is already an empty-when-absent
            // surface, and a column of dashes is noise.
            TableColumn("ECO") { game in
                Text(game.ecoCode ?? "").foregroundStyle(.secondary)
            }
            .width(min: 44, ideal: 52)
            TableColumn("Event") { Text($0.event).lineLimit(1) }
            TableColumn("Date") { game in
                Text(game.displayDate).foregroundStyle(.secondary)
            }
            .width(100)
            TableColumn("Round") { game in
                Text(game.displayRound).foregroundStyle(.secondary)
            }
            .width(60)
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
            }
            if !ids.isEmpty {
                Button {
                    onAnalyzeIDs(ids)
                } label: {
                    Label(
                        ids.count > 1 ? "Analyze \(ids.count) Games" : "Analyze",
                        systemImage: "wand.and.stars"
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
}
