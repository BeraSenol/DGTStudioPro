//
//  LiveGameInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/06/2026.
//

import SwiftUI

/// The Board inspector while a live game is being recorded (M3.3) — the
/// mirror branch's counterpart to `BoardInspectorView`, which serves loaded
/// PGNs. Pure wiring over the session's existing API: a roster summary with
/// "Edit Details" (the shared `LiveGameRosterSheet`, edit intent, committing
/// through `DGTLiveSession.updateRoster`), the growing transcript via the
/// existing `MoveHistoryView` (taps are no-ops — live games don't scrub),
/// and the lifecycle controls — Resign, Agree Draw, Discard — each behind
/// its own confirmation, per Decision #4's "manual results behind a
/// confirmation" and because all three are irreversible.
///
/// No evaluation section: live engine eval is assumed-never for v1, and the
/// transcript has no recorded evaluations to graph anyway.
///
/// With no live game the inspector shows a quiet empty state rather than a
/// skeleton of "—" rows — on the mirror branch "no game" is the normal
/// resting state, not missing data.
internal struct LiveGameInspectorView: View {

    // MARK: Environment

    @Environment(DGTLiveSession.self) private var session

    // MARK: Presentation State

    @State private var showEditSheet = false
    @State private var confirmResign = false
    @State private var confirmDraw = false
    @State private var confirmDiscard = false

    // MARK: Body

    internal var body: some View {
        if let game = session.liveGame {
            content(game)
        } else {
            ContentUnavailableView {
                Label("No Live Game", systemImage: "checkerboard.rectangle")
            } description: {
                Text("Set up the starting position on a connected board, or choose New Game.")
            }
            .accessibilityIdentifier("live.inspector.empty")
        }
    }

    // MARK: Content

    private func content(_ game: LiveGame) -> some View {
        List {
            rosterSection(game)
            movesSection(game)
            controlsSection(game)
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("live.inspector")
        .sheet(isPresented: $showEditSheet) {
            LiveGameRosterSheet(intent: .edit, initialRoster: game.roster) {
                session.updateRoster($0)
            }
        }
    }

    // MARK: Roster

    private func rosterSection(_ game: LiveGame) -> some View {
        Section {
            LabeledContent("White", value: game.roster.white)
            LabeledContent("Black", value: game.roster.black)
            LabeledContent("Event", value: game.roster.event)
            LabeledContent("Site", value: game.roster.site)
            LabeledContent("Round", value: game.roster.round.map(String.init) ?? "—")
            LabeledContent("Date", value: dateText(game.roster.date))
            LabeledContent(
                "Result",
                value: game.isFinished ? game.result.rawValue : "In progress"
            )

            Button("Edit Details…") { showEditSheet = true }
                .accessibilityIdentifier("live.inspector.editdetails")
        } header: {
            // Same "Last, First" → "First Last" display transform the
            // Library applies, so the header reads naturally either way
            // the names were entered.
            Text(
                "\(PGN.displayPlayerName(game.roster.white)) vs \(PGN.displayPlayerName(game.roster.black))"
            )
            .textCase(nil)
        }
    }

    // MARK: Moves

    private func movesSection(_ game: LiveGame) -> some View {
        Section {
            MoveHistoryView(
                moves: game.sanMoves,
                // Following the latest ply keeps the transcript auto-scrolled
                // to the newest move as it lands (the view scrolls on
                // `currentMoveIndex` changes).
                currentMoveIndex: game.sanMoves.indices.last,
                // Live games don't scrub — committed plies are final
                // (Decision #1), so taps are deliberate no-ops.
                onMoveTapped: nil
            )
            .frame(height: 240)
        } header: {
            Text("Moves")
        }
    }

    // MARK: Lifecycle Controls

    private func controlsSection(_ game: LiveGame) -> some View {
        Section {
            if !game.isFinished {
                Button("Resign…") { confirmResign = true }
                    .accessibilityIdentifier("live.inspector.resign")
                    .confirmationDialog(
                        "Who resigns?",
                        isPresented: $confirmResign,
                        titleVisibility: .visible
                    ) {
                        Button("White Resigns", role: .destructive) {
                            session.resign(.white)
                        }
                        Button("Black Resigns", role: .destructive) {
                            session.resign(.black)
                        }
                    } message: {
                        Text("Resignation records the result immediately and can't be taken back.")
                    }

                Button("Agree Draw…") { confirmDraw = true }
                    .accessibilityIdentifier("live.inspector.draw")
                    .confirmationDialog(
                        "Agree to a draw?",
                        isPresented: $confirmDraw,
                        titleVisibility: .visible
                    ) {
                        Button("Agree Draw") { session.agreeDraw() }
                    } message: {
                        Text("Records ½–½ for both players. This can't be taken back.")
                    }
            }

            Button("Discard Game…", role: .destructive) { confirmDiscard = true }
                .accessibilityIdentifier("live.inspector.discard")
                .confirmationDialog(
                    "Discard this game?",
                    isPresented: $confirmDiscard,
                    titleVisibility: .visible
                ) {
                    Button("Discard Game", role: .destructive) {
                        session.discardGame()
                    }
                } message: {
                    Text(discardWarning(game))
                }
        } header: {
            Text("Result")
        }
    }

    // MARK: Formatting

    private func dateText(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }

    private func discardWarning(_ game: LiveGame) -> String {
        game.plyCount == 0
        ? "The game will be deleted. This can't be undone."
        : "The game and its \(game.plyCount)-ply transcript will be deleted. This can't be undone."
    }
}

// MARK: - Previews

#Preview("Live Game") {
    let session = DGTLiveSession()
    session.startNewGame(
        roster: .init(
            event: "Club Night",
            site: "Antwerp",
            round: 3,
            white: "Heylen, Christophe",
            black: "Brouns, Reinaud"
        )
    )
    return LiveGameInspectorView()
        .environment(session)
        .frame(width: 320, height: 640)
}

#Preview("No Live Game") {
    LiveGameInspectorView()
        .environment(DGTLiveSession())
        .frame(width: 320, height: 480)
}
