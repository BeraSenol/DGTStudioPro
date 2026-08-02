//
//  LibraryColumnsView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 03/05/2026.
//

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
    internal let onOpen: (PGN) -> Void
    internal let onAnalyze: (PGN) -> Void
    internal let onExport: (PGN) -> Void
    internal let onDelete: (PGN) -> Void

    /// "No value to show" for the derived rows — the meaning
    /// `OpeningSection`'s em-dash carries, deliberately restated per surface
    /// (its own comment makes the same call beside `SevenTagRosterSection`'s).
    /// The roster rows never need it: `RosterSummary` speaks PGN's own `?`.
    private static let noValue = "—"

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
            gameList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340, maxHeight: .infinity)

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
            List(selection: $selectedPGNs) {
                ForEach(games) { game in
                    row(for: game)
                        .tag(game.id)
                }
            }
            .listStyle(.plain)
        }
    }

    /// Two lines, the inspector's recent-games grammar: name above, date
    /// and result below. The context menu mirrors the card's affordances so
    /// switching view modes never loses a verb.
    private func row(for game: PGN) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(game.name)
                .lineLimit(1)
            HStack {
                Text(game.displayDate)
                Spacer()
                Text(game.result.rawValue)
                    .monospaced()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Open") { onOpen(game) }
            Button("Analyze") { onAnalyze(game) }
            Button("Export…") { onExport(game) }
            Divider()
            Button("Delete", role: .destructive) { onDelete(game) }
        }
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

    /// Preview above, facts below. The preview reuses the gallery's
    /// `LibraryGamePreviewView` whole — header, board, async replay — and
    /// takes the flexible space; the facts block keeps its natural height,
    /// so a short window squeezes the board, never the text (Finder's own
    /// trade).
    private func gameDetail(_ game: PGN) -> some View {
        VStack(spacing: 0) {
            LibraryGamePreviewView(game: game, boardStyle: boardStyle)
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
                    onOpen(game)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.square")
                }
                .buttonStyle(.borderedProminent)
                .help("Open this game in its own window")

                Button {
                    onAnalyze(game)
                } label: {
                    Label("Analyze", systemImage: AnalysisGlyph.name(for: game))
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

    let games = columnsPreviewGames()

    LibraryColumnsView(
        games: games,
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 620)
    .onAppear {
        if let id = games.first?.id { selection = [id] }
    }
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Multi-Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []

    let games = columnsPreviewGames()

    LibraryColumnsView(
        games: games,
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 620)
    .onAppear {
        selection = Set(games.prefix(2).map(\.id))
    }
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("No Selection") {
    @Previewable @State var selection: Set<PGN.ID> = []

    LibraryColumnsView(
        games: columnsPreviewGames(),
        selectedPGNs: $selection,
        boardStyle: .rosewood,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Empty") {
    @Previewable @State var selection: Set<PGN.ID> = []

    LibraryColumnsView(
        games: [],
        selectedPGNs: $selection,
        boardStyle: .walnut,
        onOpen: { _ in },
        onAnalyze: { _ in },
        onExport: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 900, height: 620)
    .modelContainer(for: PGN.self, inMemory: true)
}
