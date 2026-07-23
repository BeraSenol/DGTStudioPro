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
        Section {
            LabeledContent("White", value: game.roster.white)
            LabeledContent("Black", value: game.roster.black)
            LabeledContent("Event", value: game.roster.event)
            LabeledContent("Site", value: game.roster.site)
            LabeledContent("Date", value: displayDate)
            LabeledContent("Round", value: displayRound)
            LabeledContent("Result", value: game.result.rawValue)
            
            Button("Edit Details…") {
                isEditingDetails = true
            }
            .accessibilityIdentifier(AccessibilityID.liveInspectorEditDetails)
        } header: {
            Text("Live Game")
                .textCase(nil)
        }
    }
    
    private var movesSection: some View {
        Section {
            MoveHistoryView(
                moves: game.sanMoves,
                currentMoveIndex: game.sanMoves.isEmpty
                ? nil
                : game.sanMoves.count - 1,
                onMoveTapped: nil   // live games don't scrub
            )
            .frame(height: 240)
        } header: {
            Text("Moves")
        }
    }
    
    private var lifecycleSection: some View {
        Section {
            if !game.isFinished {
                Button("Resign…") {
                    isChoosingResign = true
                }
                .accessibilityIdentifier(AccessibilityID.liveInspectorResign)
                
                Button("Agree Draw…") {
                    isConfirmingDraw = true
                }
                .accessibilityIdentifier(AccessibilityID.liveInspectorDraw)
            }
            
            Button("Discard Game…", role: .destructive) {
                isConfirmingDiscard = true
            }
            .accessibilityIdentifier(AccessibilityID.liveInspectorDiscard)
        } header: {
            Text("Game")
        }
    }
    
    // MARK: Display Helpers
    
    /// Same formatting/placeholder conventions as `PGN.displayDate`.
    private var displayDate: String {
        guard let date = game.roster.date else { return "????.??.??" }
        return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
    
    private var displayRound: String {
        guard let round = game.roster.round else { return "?" }
        return String(round)
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
