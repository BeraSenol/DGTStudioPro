import SwiftUI

/// The Board inspector's live variant: roster (with Edit Details), SAN history, result
/// controls - `BoardInspectorView`'s sidebar-list shape.
struct LiveGameInspectorView: View {
    
    // MARK: Stored Properties
    
    let game: LiveGame
    /// The number the game will carry in the Library (D58′'s max+1), threaded from the
    /// destination for the headline (17 Aug 2026). Nil omits the number - previews stand.
    var recordingNumber: Int? = nil
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
            // **ASCII hyphens in result tokens** (21 Aug 2026): `0-1`, `1-0` and `1/2-1/2` are PGN
            // tokens, and PGN spells them with a hyphen. These two were typeset with an en dash
            // while the draw button beside them was correct, so one menu showed a result score two
            // ways. The en dash keeps its own job one file over - a W–D–L record is a range.
            Button("White Resigns (0-1)", role: .destructive) {
                onResign(.white)
            }
            Button("Black Resigns (1-0)", role: .destructive) {
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
    
    /// The last committed ply. A live game is always *at* its final move -
    /// it never scrubs - and both the scroll sync and the transcript need
    /// that, each having open-coded the empty check.
    private var currentMoveIndex: Int? {
        game.sanMoves.isEmpty ? nil : game.sanMoves.count - 1
    }
    
    /// "Recording 101. Magnus Carlsen vs Ian Nepomniachtchi", the
    /// live twin of the review headline. Same formatter, so the two
    /// inspectors can't drift apart on the grammar.
    private var headline: String {
        // The number slot carries the LIBRARY ordinal since 17 Aug 2026, not the roster's
        // round - "Recording 112." for the game that will archive as 112. The formatter's
        // grammar is untouched; only the number's source moved (the round-12-vs-game-112
        // report). Round stays a roster fact everywhere else.
        GameHeadline.text(
            .recording,
            round: recordingNumber,
            white: game.roster.white,
            black: game.roster.black
        )
    }
    
    /// Shares `.moves` with the review inspector's move list - same section,
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
    
    /// `.lifecycle`, **not** `.roster`, despite the title "Game" - the section that made
    /// `InspectorSection` an enum: Resign/Draw/Discard is a set of verbs, not the game.
    private var lifecycleSection: some View {
        CollapsibleSection(.lifecycle, title: "Game") {
            // One horizontal row (17 Aug 2026, by request): three stacked rows read as a
            // settings list; side by side they read as the set of verbs they are. Equal
            // widths - ragged verb buttons read as unrelated - and a finished game degrades
            // to the lone Discard at full width.
            HStack(spacing: 8) {
                if !game.isFinished {
                    Button {
                        isChoosingResign = true
                    } label: {
                        Text("Resign")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier(AccessibilityID.liveInspectorResign)

                    Button {
                        isConfirmingDraw = true
                    } label: {
                        Text("Agree Draw")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier(AccessibilityID.liveInspectorDraw)
                }

                Button(role: .destructive) {
                    isConfirmingDiscard = true
                } label: {
                    Text("Discard Game")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier(AccessibilityID.liveInspectorDiscard)
            }
            .buttonStyle(.bordered)
            .listRowSeparator(.hidden)
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
