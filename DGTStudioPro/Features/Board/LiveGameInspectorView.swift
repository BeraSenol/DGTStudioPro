import SwiftUI

/// The Board inspector's live variant: roster (with Edit Details), SAN history, result
/// controls — `BoardInspectorView`'s sidebar-list shape.
struct LiveGameInspectorView: View {
    
    // MARK: Stored Properties
    
    let game: LiveGame
    let onUpdateRoster: (LiveGame.Roster) -> Void
    let onResign: (PieceColor) -> Void
    let onAgreeDraw: () -> Void
    let onDiscard: () -> Void
    
    // MARK: View State
    
    @State private var isEditingDetails = false
    @State private var isChoosingResign = false
    @State private var isConfirmingDraw = false
    @State private var isConfirmingDiscard = false
    
    // MARK: Body
    
    var body: some View {
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
            Button("Agree Draw (1/2-1/2)", action: onAgreeDraw)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Both players agree, the game ends 1/2-1/2.")
        }
        .confirmationDialog(
            "Discard this game?",
            isPresented: $isConfirmingDiscard
        ) {
            Button("Discard Game", role: .destructive, action: onDiscard)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The game and its moves will be lost. It won't be saved to the Library.")
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
    
    /// "Recording 101. Magnus Carlsen vs Ian Nepomniachtchi", the
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
    
    /// Shares `.moves` with the review inspector's move list — same section,
    /// two states of the same game, and the review side is where a reader who
    /// folded it away would expect it still folded.
    private var movesSection: some View {
        CollapsibleSection(.moves, title: "Moves") {
            MoveHistoryView(
                moves: game.sanMoves,
                currentMoveIndex: currentMoveIndex,
                onMoveTapped: nil,   // live games don't scrub
                scrollsIndependently: false
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
            .listRowSeparator(.hidden)
        }
    }
    
    /// `.lifecycle`, **not** `.roster`, despite the title "Game" — the section that made
    /// `InspectorSection` an enum: Resign/Draw/Discard is a set of verbs, not the game.
    private var lifecycleSection: some View {
        CollapsibleSection(.lifecycle, title: "Game") {
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
    .environment(InspectorSectionCollapse.preview)
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
    .environment(InspectorSectionCollapse.preview)
}
