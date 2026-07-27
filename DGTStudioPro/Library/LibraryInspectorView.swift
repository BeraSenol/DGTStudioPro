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
    
    /// The tab's analysis queue. The inspector renders the queue's view
    /// of the displayed game and routes every control through it — it
    /// owns no driver of its own since M-batch (see
    /// `AnalysisQueueController`, decision 1). That promotion also
    /// retired the `pendingAnalysisID` one-shot relay this view used to
    /// carry: toolbar and context-menu analyze only needed a routed
    /// request because the driver lived in this view's `@State`; with
    /// the controller reachable directly, they simply enqueue.
    internal let queue: AnalysisQueueController
    
    // MARK: Initializers
    internal init(
        pgn: PGN? = nil,
        queue: AnalysisQueueController
    ) {
        self.pgn = pgn
        self.queue = queue
    }
    
    // MARK: Body
    internal var body: some View {
        // D26′ — the empty branch renders *outside* the `List`. Inside one it
        // is a top-aligned row with sidebar chrome behind it, which is what
        // made this inspector disagree with Board's centred column.
        if let pgn {
            List {
                // .id forces SwiftUI to re-init this section when the
                // user selects a different game, resetting per-game view
                // state (the name-edit draft). It no longer tears down an
                // analysis — the queue lives on the tab and keeps
                // crunching while the user browses (decision 1).
                LoadedSection(pgn: pgn, queue: queue)
                    .id(pgn.id)
            }
            .listStyle(.sidebar)
        } else {
            emptyState
        }
    }
    
    // MARK: Instance Methods
    private var emptyState: some View {
        InspectorEmptyState(
            title: "No Game Selected",
            systemImage: "document.fill",
            message: "Select a game from the library to view its details and analysis.",
            identifier: AccessibilityID.libraryInspectorEmpty
        )
    }
}

private struct LoadedSection: View {
    
    // MARK: Stored Properties
    @Bindable var pgn: PGN
    let queue: AnalysisQueueController
    
    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut
    @FocusState private var isNameFieldFocused: Bool
    @State private var isEditingName: Bool = false
    @State private var draftName: String = ""
    
    // MARK: Body
    var body: some View {
        Group {
            identitySection
            
            // D22′ — the seven tags as one object, under the game's own name.
            // "Game Details" labelled what the rows already say they are;
            // the name is the one thing the section couldn't tell you, and
            // putting it here is what lets the rename pencil sit beside what
            // it renames. Board and the live inspector name their game in
            // this same header, so the three now read alike.
            SevenTagRosterSection(
                roster: RosterSummary(pgn),
                headline: pgn.name
            ) {
                InspectorEditButton(
                    label: "Rename",
                    identifier: AccessibilityID.libraryInspectorRename
                ) {
                    beginEdit()
                }
            }
            
            evaluationSection
        }
    }
    
    // MARK: Identity
    
    /// Open, and the rename field while one is in progress. The name's
    /// *display* is the roster header now; what stays here is the editor,
    /// because a `TextField` in a sidebar section header is a control at
    /// caption size in a header whose height must not move. The header keeps
    /// showing the committed name while the field holds the draft — before
    /// and after, visible together.
    ///
    /// `PGN.name` is still deliberately not one of the seven tags: it is a
    /// user label outside the content hash, which is why the rename needs no
    /// `refreshHash` and why the pencil is its own registry entry rather than
    /// a member of the Edit Info family.
    private var identitySection: some View {
        Section {
            openButton
            if isEditingName {
                nameEditor
            }
        }
    }
    
    // MARK: Open Affordance
    
    /// "Open" button in the Library inspector. Asks macOS to open a
    /// window for this game's `persistentModelID`. macOS handles dedup —
    /// re-clicking activates the existing window. With "Prefer Tabs:
    /// Always," multiple opened games merge as native tabs of one window.
    private var openButton: some View {
        Button {
            openWindow(value: pgn.persistentModelID)
        } label: {
            Label("Open", systemImage: "checkerboard.rectangle")
        }
        .help("Open this game in a new window")
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
    
    /// One row, four shapes, all driven by the queue's view of this game:
    /// Analyze/Re-analyze enqueues (a single game is a batch of one); a
    /// queued game shows its place in line with a way out; the running
    /// game shows the per-ply progress and the skip control; a failure
    /// shows its message with Retry. "Re-analyze" keys off recorded
    /// evaluations rather than a driver's `.done` — the driver is gone
    /// from this view, and the data reads correctly for games analyzed in
    /// an earlier session or imported with `[%eval]` tags, which the old
    /// status-based label never did.
    @ViewBuilder
    private var analysisControlRow: some View {
        switch queue.status(of: pgn.id) {
        case .running:
            HStack(spacing: 8) {
                ProgressView(value: queue.currentProgress)
                Button {
                    queue.skipCurrent()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop analyzing this game")
            }
            
        case .waiting(let position):
            HStack(spacing: 8) {
                Label("Queued — #\(position) in line", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    queue.removeWaiting(pgn.id)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove from the analysis queue")
            }
            
        case .finished(.failed(let message)):
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    queue.enqueue([pgn], modelContext: modelContext)
                }
                .buttonStyle(.borderless)
            }
            
        case .notQueued, .finished(.done), .finished(.cancelled):
            Button {
                queue.enqueue([pgn], modelContext: modelContext)
            } label: {
                Label(
                    hasRecordedAnalysis ? "Re-analyze" : "Analyze",
                    systemImage: "wand.and.stars"
                )
            }
        }
    }
    
    /// Whether any ply of this game carries a recorded evaluation —
    /// what "Re-analyze" keys off (see `analysisControlRow`).
    private var hasRecordedAnalysis: Bool {
        pgn.evaluations.contains { $0 != nil }
    }
    
    // MARK: Instance Methods
    /// Renamed from `nameRow` with the display branch: it is only an editor
    /// now, and the `if` that used to choose between the two moved to the
    /// call site, where the row can be absent rather than empty.
    private var nameEditor: some View {
        HStack(spacing: 6) {
            TextField("Name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit { commitEdit() }
            Button("Done") { commitEdit() }
                .buttonStyle(.borderless)
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
        ),
        queue: AnalysisQueueController()
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
        ),
        queue: AnalysisQueueController()
    )
    .frame(width: 300, height: 500)
}

#Preview("Empty") {
    LibraryInspectorView(queue: AnalysisQueueController())
        .frame(width: 300, height: 400)
}
