import SwiftUI
import SwiftData

struct BoardInspectorView: View {
    
    // MARK: Stored Properties
    let pgn: PGN?
    let evaluations: [Double]
    let moves: [String]
    let currentMoveIndex: Int?
    let style: BoardStyle
    let onMoveTapped: ((Int) -> Void)?
    
    /// The edit request: presentation and the write belong to `BoardDestination` (modals are
    /// destination furniture); this view only asks, which keeps it canvas-renderable. The Board
    /// presents no editor at all.

    var body: some View {
        List {
            metadataSection
            OpeningSection(opening: pgn?.opening)
            evaluationSection
            movesSection
        }
        .listStyle(.sidebar)
        // The list is the only scroller, so it follows the current ply.
        .scrollsToCurrentMove(currentMoveIndex)
    }
    
    // MARK: Instance Methods
    /// The roster under the headline - the same shape and place as the live inspector's, so
    /// the two metadata surfaces read as one idea in two states.
    private var metadataSection: some View {
        // The action slot is empty and kept: an empty `@ViewBuilder` slot is the honest
        // statement that this host has no verb.
        SevenTagRosterSection(
            roster: pgn.map { RosterSummary($0) },
            headline: headline
        )
    }
    
    /// The headline; falls back to a bare noun with no game - "? vs ?" would over-claim.
    private var headline: String {
        guard let pgn else { return "Game" }
        // The number slot carries the LIBRARY ordinal since 17 Aug 2026 - "Reviewing 47." for
        // game 47 - the live headline's rule, applied to its review twin the same day (round
        // is a rivalry counter, and the two inspectors must not number differently). A game
        // without an ordinal omits the number, which the grammar already does for nil.
        return GameHeadline.text(
            .reviewing, round: pgn.libraryIndex, white: pgn.white, black: pgn.black
        )
    }
    
    /// The magnifier renders only over a game the Library knows about and doesn't exist otherwise -
    /// an affordance that can't act shouldn't sit greyed out.
    private var evaluationSection: some View {
        CollapsibleSection(.evaluation, title: "Evaluation") {
            EvaluationGraphView(
                evaluations: evaluations,
                currentMoveIndex: currentMoveIndex,
                style: style
            )
            .frame(height: 140)
        } actions: {
            if let pgn {
                EvaluationMagnifierButton(gameID: pgn.persistentModelID)
            }
        }
    }
    
    /// `MoveHistoryView` doesn't scroll itself, so the header keeps the section's controls reachable.
    private var movesSection: some View {
        // Was a hand-rolled `HStack` reimplementing `InspectorSectionHeader` and disagreeing on three
        // counts - predated the shared type, never migrated.
        CollapsibleSection(.moves, title: "Moves") {
            MoveHistoryView(
                moves: moves,
                currentMoveIndex: currentMoveIndex,
                onMoveTapped: onMoveTapped,
                scrollsIndependently: false
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listRowSeparator(.hidden)
        } actions: {
            // No pencil, deliberately and permanently: movetext is read-only on this destination in both
            // branches (append-only live; the editor is Get Info's for review).
        }
    }
}

// MARK: Previews
#Preview("Game Data") {
    BoardInspectorView(
        pgn: PGN(
            event: "World Championship",
            site: "Dubai",
            round: 7,
            white: "Carlsen",
            black: "Nepomniachtchi",
            result: .ongoing
        ),
        evaluations: [
            0.50, 0.52, 0.51, 0.49, 0.50, 0.52, 0.50, 0.48,
            0.46, 0.44, 0.46, 0.44, 0.42, 0.44, 0.43, 0.45,
            0.42, 0.40, 0.42, 0.44, 0.41, 0.38, 0.40, 0.42,
            0.38, 0.35, 0.37, 0.40, 0.36, 0.32, 0.35, 0.30,
            0.34, 0.42, 0.50, 0.58, 0.72, 0.88, 0.96
        ],
        moves: [
            "e4", "e5", "Nf3", "Nc6", "Bb5", "a6",
            "Ba4", "Nf6", "O-O", "Be7", "Re1", "b5",
            "Bb3", "d6", "c3", "O-O", "h3", "Nb8",
            "d4", "Nbd7"
        ],
        currentMoveIndex: 14,
        style: .walnut,
        onMoveTapped: { _ in }
    )
    .frame(width: 300, height: 600)
    .environment(InspectorSectionCollapse.preview)
}

#Preview("No Game Data") {
    BoardInspectorView(
        pgn: nil,
        evaluations: [],
        moves: [],
        currentMoveIndex: nil,
        style: .walnut,
        onMoveTapped: nil
    )
    .frame(width: 300, height: 400)
    .environment(InspectorSectionCollapse.preview)
}
