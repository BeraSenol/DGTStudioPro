//
//  LibraryInspectorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 12/04/2026.
//

import AppKit
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
    @State private var isShowingPGN: Bool = true
    
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
                // No local padding: the trailing inset lives on
                // `InspectorEditButtonView` for all five pencils. An 8 pt
                // one here used to stack on top of the shared 10 and put
                // this one alone at 18.
                InspectorEditButtonView(
                    label: "Rename",
                    identifier: AccessibilityID.libraryInspectorRename
                ) {
                    beginEdit()
                }
            }
            
            OpeningSection(opening: pgn.opening)
            evaluationSection
            pgnSection
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
    private var reviewButton: some View {
        Button {
            openWindow(value: pgn.persistentModelID)
        } label: {
            Label("Review", systemImage: "checkerboard.rectangle")
        }
        .help("Review this game in a new window")
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
            
            HStack {
                Spacer()
                reviewButton
                analysisControlRow
                Spacer()
            }
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
    
    // MARK: PGN Section
    
    /// The game as a file: `PGN.pgnText`, byte-identical to what Export
    /// writes (D24′). Deliberately not its own rendering of the model — an
    /// inspector that formatted its own tag block would be a third PGN shape
    /// in the app, free to drift from the one the reference files pin, and
    /// the entire value of showing raw text is that it is what the file will
    /// say. Side effect worth having: a serializer defect is now visible in
    /// the sidebar instead of only in an exported file nobody re-reads.
    ///
    /// Last, and **open by default** — reversed 30 July from the M1
    /// collapsed default by Bera's call: with the raw text a glance away,
    /// having it visible beat protecting the first screenful. The
    /// disclosure chevron keeps earning its place in the other direction
    /// (hide the longest section when it's in the way).
    ///
    /// The collapse is a plain `if`, not `Section(isExpanded:)`. The platform
    /// control only appears on hover, and a section whose one affordance is
    /// invisible until the pointer happens to cross it is a section that
    /// reads as a truncated line of text — which is exactly how this one
    /// read. Every other section in this inspector is a plain `Section` with
    /// no disclosure chrome, so dropping the binding leaves no native control
    /// to collide with the one drawn here.
    ///
    /// Expansion resets per game, because `LoadedSection` carries
    /// `.id(pgn.id)` — the same reset the rename draft gets. Holding it open
    /// across a selection change would mean lifting the flag above that
    /// `.id` and threading a binding down, which is more machinery than the
    /// affordance earns.
    private var pgnSection: some View {
        Section {
            // The `if` *is* the collapse now, so it also does the gating the
            // ternary used to: this view's body re-runs on every
            // `queue.currentProgress` tick while *this* game is analyzing,
            // and `pgnText` rebuilds the whole export string each pass.
            if isShowingPGN {
                rawPGNText
            }
        } header: {
            InspectorSectionHeader("PGN") {
                // `InspectorSectionHeader` stacks its actions at spacing 0 —
                // right for a lone pencil, flush for two glyphs.
                HStack(spacing: 12) {
                    copyPGNButton
                    disclosureButton
                }
                .padding(.trailing, 8)
            }
        }
    }
    
    /// The bytes themselves, extracted so the section body is the shape of
    /// the decision — open or not — rather than a modifier chain wrapped in
    /// an `if`.
    private var rawPGNText: some View {
        Text(pgn.pgnText)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
        // A `List` row proposes a height, and a multi-line `Text` that
        // accepts one collapses to a single truncated line — which is
        // what this section did until `fixedSize` told it to take its
        // ideal height instead. Vertical only: the horizontal proposal
        // still comes from the frame below, so movetext lines wrap at
        // the inspector's width rather than running off it.
        // `lineLimit(nil)` is stated beside it because the truncation
        // reads like an inherited limit, and the next person to see it
        // will go looking for one.
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(AccessibilityID.libraryInspectorPGN)
    }
    
    /// The always-visible disclosure. One chevron rotated rather than two
    /// symbols swapped, so the state change is a continuous motion the eye
    /// tracks instead of a substitution it has to re-read — and so there is
    /// one glyph to keep consistent if a second collapsible section ever
    /// wants the same control.
    ///
    /// Leading of the copy button, which keeps the *action* glyph rightmost
    /// where the roster header above puts its rename pencil.
    private var disclosureButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                isShowingPGN.toggle()
            }
        } label: {
            Image(systemName: "chevron.right")
                .rotationEffect(.degrees(isShowingPGN ? 90 : 0))
        }
        .buttonStyle(.borderless)
        // `InspectorEditButtonView`'s reason: a glyph at header font size is an
        // ~11 pt mouse target.
        .font(.body)
        .help(isShowingPGN ? "Hide PGN" : "Show PGN")
        .accessibilityLabel(isShowingPGN ? "Hide PGN" : "Show PGN")
        .accessibilityIdentifier(AccessibilityID.libraryInspectorPGNDisclosure)
    }
    
    /// Puts the exported bytes on the pasteboard, so a game reaches a mail
    /// draft or an analysis site without a round trip through the
    /// filesystem. In the header rather than beside the text so it works
    /// while the section is collapsed.
    ///
    /// `NSPasteboard` because SwiftUI has no pasteboard-write API a button
    /// action can call: `.copyable(_:)` routes through the system Copy
    /// command and needs the view focused, which a sidebar section header
    /// cannot promise. Not an `InspectorEditButtonView` — that type hardcodes
    /// the pencil precisely so three inspectors' edit affordances cannot
    /// drift, and widening it to take a symbol would turn a named affordance
    /// into a generic icon button and lose exactly that guarantee. Extract
    /// only if a second copy affordance appears.
    private var copyPGNButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pgn.pgnText, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        // `InspectorEditButtonView`'s reason: a glyph at header font size is an
        // ~11 pt mouse target.
        .font(.body)
        .help("Copy PGN")
        .accessibilityLabel("Copy PGN")
        .accessibilityIdentifier(AccessibilityID.libraryInspectorCopyPGN)
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
    .frame(width: 300, height: 700)
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
    .frame(width: 300, height: 700)
}

#Preview("Empty") {
    LibraryInspectorView(queue: AnalysisQueueController())
        .frame(width: 300, height:700)
}

/// The raw-PGN section against a game that actually has movetext — the other
/// three previews carry none, so the section renders a tag block over an
/// empty body in all of them. An odd ply count is the case worth seeing: the
/// serializer's white-only final line (`4. Qxf7#`), with the mate suffix
/// emitted verbatim.
///
/// The section starts collapsed, as it does in the app; the canvas is live,
/// so expanding it is a click.
#Preview("Raw PGN") {
    LibraryInspectorView(
        pgn: PGN(
            event: "Club Championship",
            site: "Antwerp",
            date: .now,
            round: 3,
            white: "Senol, Bera",
            black: "Reinaud, Lorenzo",
            moves: ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"],
            result: .whiteWins,
            timeControl: "-",
            board: "DGT 3000448278"
        ),
        queue: AnalysisQueueController()
    )
    .frame(width: 320, height:700)
}
