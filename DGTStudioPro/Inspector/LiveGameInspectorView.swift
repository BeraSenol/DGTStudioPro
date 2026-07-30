//
//  LiveGameInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/06/2026.
//

import SwiftUI

/// The Board inspector's live-game variant (M3.3), shown when a live game
/// exists and no PGN is loaded in the tab. Mirrors `BoardInspectorView`'s
/// sidebar-list shape: a roster summary (with Edit Details), the SAN
/// transcript, and the game-lifecycle controls.
///
/// The transcript reuses `MoveHistoryView` with taps disabled — live games
/// don't scrub (the board always mirrors the physical pieces). The three
/// lifecycle actions each sit behind a confirmation; the destructive
/// choices can't be undone (Decision #1: no takebacks, FIDE semantics).
///
/// Sheets and confirmations are owned locally; the actions themselves are
/// closures into `DGTLiveSession` so every game mutation keeps flowing
/// through the session (and its diagnostic timeline).
internal struct LiveGameInspectorView: View {
    
    // MARK: Stored Properties
    
    internal let game: LiveGame
    internal let onUpdateRoster: (LiveGame.Roster) -> Void
    internal let onResign: (PieceColor) -> Void
    internal let onAgreeDraw: () -> Void
    internal let onDiscard: () -> Void
    
    // MARK: View State
    
    @State private var isEditingDetails = false
    @State private var isChoosingResign = false
    @State private var isConfirmingDraw = false
    @State private var isConfirmingDiscard = false
    
    // MARK: Body
    
    internal var body: some View {
        List {
            rosterSection
            movesSection
            lifecycleSection
        }
        .listStyle(.sidebar)
        .scrollsToCurrentMove(currentMoveIndex)
        .accessibilityIdentifier(AccessibilityID.liveInspector)
        .sheet(isPresented: $isEditingDetails) {
            EditLiveGameDetailsSheet(
                initialRoster: game.roster,
                onSave: onUpdateRoster
            )
        }
        .confirmationDialog(
            "Who resigns?",
            isPresented: $isChoosingResign
        ) {
            Button("White Resigns (0–1)", role: .destructive) {
                onResign(.white)
            }
            Button("Black Resigns (1–0)", role: .destructive) {
                onResign(.black)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Resignation ends the game immediately and can't be undone.")
        }
        .confirmationDialog(
            "Agree to a draw?",
            isPresented: $isConfirmingDraw
        ) {
            Button("Agree Draw (½–½)", action: onAgreeDraw)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Both players agree — the game ends ½–½.")
        }
        .confirmationDialog(
            "Discard this game?",
            isPresented: $isConfirmingDiscard
        ) {
            Button("Discard Game", role: .destructive, action: onDiscard)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The game and its moves will be lost — it won't be saved to the Library.")
        }
    }
    
    // MARK: Sections
    
    private var rosterSection: some View {
        SevenTagRosterSection(
            roster: RosterSummary(game.roster, result: game.result),
            headline: headline
        ) {
            InspectorEditButtonView(
                label: "Edit Details",
                identifier: AccessibilityID.liveInspectorEditDetails
            ) {
                isEditingDetails = true
            }
        }
    }
    
    /// The last committed ply. A live game is always *at* its final move —
    /// it never scrubs — and both the scroll sync and the transcript need
    /// that, each having open-coded the empty check.
    private var currentMoveIndex: Int? {
        game.sanMoves.isEmpty ? nil : game.sanMoves.count - 1
    }
    
    /// D20′ — "Recording 101. Magnus Carlsen vs Ian Nepomniachtchi", the
    /// live twin of the review headline. Same formatter, so the two
    /// inspectors can't drift apart on the grammar.
    private var headline: String {
        GameHeadline.text(
            .recording,
            round: game.roster.round,
            white: game.roster.white,
            black: game.roster.black
        )
    }
    
    private var movesSection: some View {
        Section {
            MoveHistoryView(
                moves: game.sanMoves,
                currentMoveIndex: currentMoveIndex,
                onMoveTapped: nil,   // live games don't scrub
                scrollsIndependently: false
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listRowSeparator(.hidden)
        } header: {
            Text("Moves")
        }
    }
    
    private var lifecycleSection: some View {
        Section {
            if !game.isFinished {
                Button("Resign") {
                    isChoosingResign = true
                }
                .accessibilityIdentifier(AccessibilityID.liveInspectorResign)
                
                Button("Agree Draw") {
                    isConfirmingDraw = true
                }
                .accessibilityIdentifier(AccessibilityID.liveInspectorDraw)
            }
            
            Button("Discard Game", role: .destructive) {
                isConfirmingDiscard = true
            }
            .accessibilityIdentifier(AccessibilityID.liveInspectorDiscard)
        } header: {
            Text("Game")
        }
    }
}

// MARK: Previews

#Preview("In Progress") {
    LiveGameInspectorView(
        game: LiveGame(
            roster: .init(
                event: "Club Night",
                site: "Home",
                round: 3,
                white: "Alice",
                black: "Bob"
            )
        ),
        onUpdateRoster: { _ in },
        onResign: { _ in },
        onAgreeDraw: {},
        onDiscard: {}
    )
    .frame(width: 300, height: 600)
}

#Preview("Finished") {
    let game: LiveGame = {
        let finished = LiveGame(
            roster: .init(white: "Alice", black: "Bob")
        )
        finished.resign(.black)
        return finished
    }()
    
    LiveGameInspectorView(
        game: game,
        onUpdateRoster: { _ in },
        onResign: { _ in },
        onAgreeDraw: {},
        onDiscard: {}
    )
    .frame(width: 300, height: 600)
}
