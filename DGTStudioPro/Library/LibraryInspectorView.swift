//
//  LibraryInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import SwiftData
import SwiftUI

internal struct LibraryInspectorView: View {

    // MARK: Stored Properties
    internal let pgn: PGN?

    // MARK: Initializers
    internal init(pgn: PGN? = nil) {
        self.pgn = pgn
    }

    // MARK: Body
    internal var body: some View {
        List {
            if let pgn {
                // .id forces SwiftUI to re-init this section (and its
                // GameAnalysisDriver @State) when the user selects a
                // different game. The prior section's .onDisappear fires
                // on its way out, cancelling any in-flight analysis.
                LoadedSection(pgn: pgn)
                    .id(pgn.id)
            } else {
                emptySection
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: Instance Methods
    private var emptySection: some View {
        Section {
            Text("No game selected")
                .foregroundStyle(.secondary)
        } header: {
            Text("Game Details")
        }
    }
}

private struct LoadedSection: View {

    // MARK: Stored Properties
    @Bindable var pgn: PGN

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    @State private var driver = GameAnalysisDriver()
    @FocusState private var isNameFieldFocused: Bool
    @State private var isEditingName: Bool = false
    @State private var draftName: String = ""

    // MARK: Body
    var body: some View {
        Group {
            Section {
                nameRow
                LabeledContent("Event",  value: pgn.event)
                LabeledContent("Site",   value: pgn.site)
                LabeledContent("Date",   value: pgn.displayDate)
                LabeledContent("Round",  value: pgn.displayRound)
                LabeledContent("White",  value: pgn.whiteDisplayName)
                LabeledContent("Black",  value: pgn.blackDisplayName)
                LabeledContent("Result", value: pgn.result.rawValue)
            } header: {
                Text("Game Details")
            }

            evaluationSection
        }
        .onDisappear {
            // Fire-and-forget — the engine's 500ms grace period lets `quit`
            // drain cleanly without blocking view teardown. If the view
            // is replaced for a different PGN, the prior driver's task
            // gets cancelled here before the new driver takes over.
            Task { await driver.shutdown() }
        }
    }

    // MARK: Evaluation Section
    @ViewBuilder
    private var evaluationSection: some View {
        Section {
            EvaluationGraphView(
                evaluations: pgn.evaluations.map {
                    $0?.whiteWinProbability ?? 0.5
                },
                currentMoveIndex: nil,
                style: boardStyle
            )
            .frame(height: 100)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))

            analysisControlRow
        } header: {
            Text("Evaluation")
        }
    }

    @ViewBuilder
    private var analysisControlRow: some View {
        switch driver.status {
        case .idle, .done:
            Button {
                driver.analyze(pgn: pgn, modelContext: modelContext)
            } label: {
                Label(
                    driver.status == .done ? "Re-analyze" : "Analyze",
                    systemImage: "wand.and.stars"
                )
            }

        case .analyzing(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                Button {
                    driver.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop analysis")
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    driver.analyze(pgn: pgn, modelContext: modelContext)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: Instance Methods
    @ViewBuilder
    private var nameRow: some View {
        if isEditingName {
            HStack(spacing: 6) {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFieldFocused)
                    .onSubmit { commitEdit() }
                Button("Done") { commitEdit() }
                    .buttonStyle(.borderless)
            }
        } else {
            HStack(spacing: 6) {
                Text(pgn.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button {
                    beginEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Rename")
            }
        }
    }

    private func beginEdit() {
        draftName = pgn.name
        isEditingName = true
        isNameFieldFocused = true
    }

    private func commitEdit() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            pgn.name = trimmed
        }
        isEditingName = false
    }
}

// MARK: Previews
#Preview("With Game") {
    LibraryInspectorView(
        pgn: PGN(
            event: "World Championship",
            site: "Dubai",
            round: 7,
            white: "Carlsen",
            black: "Nepomniachtchi",
            result: .ongoing
        )
    )
    .frame(width: 300, height: 500)
}

#Preview("Custom Name") {
    LibraryInspectorView(
        pgn: PGN(
            event: "World Championship",
            site: "Reykjavik",
            round: 6,
            white: "Fischer",
            black: "Spassky",
            name: "Game of the Century",
            result: .whiteWins
        )
    )
    .frame(width: 300, height: 500)
}

#Preview("Empty") {
    LibraryInspectorView()
        .frame(width: 300, height: 400)
}
