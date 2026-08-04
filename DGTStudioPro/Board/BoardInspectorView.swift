//
//  BoardInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/04/2026.
//

import SwiftUI
import SwiftData

internal struct BoardInspectorView: View {
    
    // MARK: Stored Properties
    internal let pgn: PGN?
    internal let evaluations: [Double]
    internal let moves: [String]
    internal let currentMoveIndex: Int?
    internal let style: BoardStyle
    internal let onMoveTapped: ((Int) -> Void)?
    
    /// The edit request. Presentation belongs to `BoardDestination` (D15′ —
    /// modals are destination furniture) and so does the write; this view only
    /// asks, which is what keeps it renderable in a canvas.
    ///
    /// Optional and defaulted — the `LiveGameHUDView.onRetryArchive`
    /// precedent — so a host with nothing to offer omits it and the button
    /// simply doesn't render. That replaces the retired toolbar item's
    /// `.disabled(boardPGN == nil)`: an affordance that can't act now doesn't
    /// exist rather than sitting there greyed out.
    ///
    /// `onEditMoves` was the second of these until M10 made movetext
    /// read-only here and the 4 Aug review found it wired to nothing. It is
    /// not coming back as a seam: the Library owns that editor now, so a
    /// closure here would be a request no destination is prepared to answer.
    internal var onEditInfo: (() -> Void)? = nil
    
    internal var body: some View {
        List {
            metadataSection
            OpeningSection(opening: pgn?.opening)
            evaluationSection
            movesSection
        }
        .listStyle(.sidebar)
        // The list is the only scroller now, so it's the thing that has to
        // follow the current ply.
        .scrollsToCurrentMove(currentMoveIndex)
    }
    
    // MARK: Instance Methods
    /// The action slot D22′ built and named this exact button for: "the review
    /// side's eventual 'Edit Info…' will be its own registry entry". It rides
    /// the section header, trailing the headline — the same shape and the
    /// same place as the live inspector's Edit Details, so the two metadata
    /// surfaces read as one idea in two states.
    private var metadataSection: some View {
        SevenTagRosterSection(
            roster: pgn.map { RosterSummary($0) },
            headline: headline
        ) {
            if let onEditInfo {
                InspectorEditButtonView(
                    label: "Edit Info",
                    identifier: AccessibilityID.boardEditInfoButton,
                    action: onEditInfo
                )
            }
        }
    }
    
    /// D20′ — "Reviewing 1. Magnus Carlsen vs Ian Nepomniachtchi". Falls
    /// back to a bare noun with no game loaded (the preview's empty state):
    /// a headline naming "? vs ?" would over-claim there.
    private var headline: String {
        guard let pgn else { return "Game" }
        return GameHeadline.text(
            .reviewing, round: pgn.round, white: pgn.white, black: pgn.black
        )
    }
    
    /// The magnifier renders only over a game the Library knows about, and it
    /// simply doesn't exist otherwise — `onEditInfo`'s rule (an affordance that
    /// can't act now shouldn't sit there greyed out), applied to the same
    /// condition. A live game has no `PGN` until it archives, so there is
    /// nothing for the window to resolve; the bar and the inspector graph are
    /// still there, which is what a live game's evaluation surface was anyway.
    private var evaluationSection: some View {
        CollapsibleSection(.evaluation, title: "Evaluation") {
            EvaluationGraphView(
                evaluations: evaluations,
                currentMoveIndex: currentMoveIndex,
                style: style
            )
            .frame(height: 160)
        } actions: {
            if let pgn {
                EvaluationMagnifierButton(gameID: pgn.persistentModelID)
            }
        }
    }
    
    /// Edit Moves lives in the **header** — where the roster section's action
    /// now sits too, so what was once a deliberate break is the inspector's
    /// one rule. The reason it arrived there first still holds on its own:
    /// `MoveHistoryView` doesn't scroll itself (`scrollsIndependently: false`)
    /// — the enclosing List does — so a row after it is a row after every ply,
    /// which on a hundred-move game is an affordance the user has to go
    /// looking for.
    private var movesSection: some View {
        // Was a hand-rolled `HStack` reimplementing `InspectorSectionHeader` —
        // and disagreeing with it on three counts: `Spacer(minLength: 0)`
        // against 8, no `.textCase(nil)`, no `.lineLimit(1)`. It predated the
        // shared type and was never migrated, so this file's roster header went
        // through the type while its moves header quietly didn't.
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
            // No pencil here, deliberately and permanently: movetext is
            // read-only on this destination in **both** branches, live and
            // review, and the editor lives in the Library.
            //
            // **Live was always the stranger of the two.** Decision #1 says
            // the physical board is truth and the live game is append-only —
            // no takebacks, ever — and an editor that could rewrite the
            // movetext mid-game was the one surface that could contradict the
            // board it mirrors. In review the argument is weaker but points
            // the same way: a game on the board is a game being *read*, and
            // the Library is where its bytes are managed.
            //
            // The seam went with the pencil. M10 removed the control and left
            // `onEditMoves` behind "for the length of one pass" as the seam
            // either answer would use, which the 4 Aug review correctly called
            // a D40′ lie one layer down — a wired closure nothing could call.
            // D18′'s validator is not surface-less any more; it is the
            // Library's, and `library.editMoves` is where it is reached.
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
        onMoveTapped: { _ in },
        onEditInfo: {}
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
