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
    
    /// How many games the destination's selection holds (2 Aug 2026).
    /// `pgn` arrives nil for empty *and* multiple selections — the
    /// destination's rule — so without the count this view could not tell
    /// "select something" from "you selected twelve things". Defaulted to
    /// zero so the previews and the empty state read unchanged; the
    /// destination always passes it.
    internal let selectionCount: Int
    
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
        selectionCount: Int = 0,
        queue: AnalysisQueueController
    ) {
        self.pgn = pgn
        self.selectionCount = selectionCount
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
        } else if selectionCount > 1 {
            multiSelectionState
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
    
    /// The counting variant: same D26′ chrome, same outside-the-`List`
    /// contract, and the symbol the columns detail pane uses for the same
    /// state — two surfaces, one vocabulary for "you selected many".
    private var multiSelectionState: some View {
        InspectorEmptyState(
            title: "\(selectionCount) Games Selected",
            systemImage: "document.on.document.fill",
            message: "The toolbar's Analyze, Export and Delete act on the whole selection.",
            identifier: AccessibilityID.libraryInspectorMulti
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
                // No local padding: the trailing inset lives on
                // `InspectorSectionHeader.actionsInset`, for every header
                // control in the app rather than for the five pencils. An
                // 8 pt one here used to stack on top of the pencil's own 10
                // and put this one alone at 18 — and the fix for *that*
                // still left the number on the pencil, where it silently
                // stopped being an edge inset the moment a second control
                // followed one. Two corrections, one line.
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
    ///
    /// **The one section in the app that is not a `CollapsibleSection`**, and
    /// the exception is structural rather than an oversight: it has no header,
    /// because it has nothing to name — it is empty except while a rename is in
    /// progress. A chevron here would be a control for hiding a section that is
    /// already invisible, permanently attached to a header that would exist
    /// only to carry it.
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
        // Collapsing this one also hides Review and Analyze, which live in its
        // body rather than its header. Accepted rather than worked around: they
        // are controls *about the analysis*, the section says so, and the
        // alternative — promoting them to the header to keep them reachable —
        // would put two more glyphs beside a chevron to protect against a state
        // the reader chose and can undo with one click.
        CollapsibleSection(.evaluation, title: "Evaluation") {
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
        } actions: {
            EvaluationMagnifierButton(gameID: pgn.persistentModelID)
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
                // "Analyzed" rather than "Re-analyze" since 3 Aug 2026 —
                // state over verb; the button still re-runs the pass.
                AnalysisLabel(analyzed: hasRecordedAnalysis)
            }
        }
    }
    
    /// Whether any ply of this game carries a recorded evaluation —
    /// what "Re-analyze" and the gear glyph key off. Delegated to
    /// `AnalysisGlyph` since the glyph unified this spelling with the
    /// search filter's.
    private var hasRecordedAnalysis: Bool {
        AnalysisGlyph.isAnalyzed(pgn)
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
    /// read. That argument is now the app's, not this section's:
    /// `InspectorSectionHeader` draws the chevron for every collapsible
    /// section, so the reason survives the move intact.
    ///
    /// What did **not** survive is this paragraph's closing sentence, struck
    /// here rather than quietly edited: it said "every other section in this
    /// inspector is a plain `Section` with no disclosure chrome, so dropping
    /// the binding leaves no native control to collide with the one drawn
    /// here." That was a claim about the *neighbours*, and D45′ is in the
    /// business of giving all of them the same control — so it was true when
    /// written, load-bearing for the choice it justified, and false the moment
    /// the milestone it survived into landed.
    ///
    /// Expansion **no longer resets per game** — that is D45′'s one behaviour
    /// change here, and it is the price of there being one collapse mechanism
    /// instead of two. The old flag was `@State` under `LoadedSection`'s
    /// `.id(pgn.id)`, so it reset on every selection; the shared store is
    /// app-wide and persisted, so a folded PGN section stays folded across
    /// games and across launches. Recorded as a change rather than discovered
    /// as a surprise: the earlier doc argued a reset was right because holding
    /// it open "would mean lifting the flag above that `.id` and threading a
    /// binding down, which is more machinery than the affordance earns". That
    /// machinery now exists for nine other sections, so the argument that
    /// justified the reset has been paid for elsewhere.
    private var pgnSection: some View {
        // `CollapsibleSection` does the gating the ternary used to, which still
        // matters for the reason it always did: this view's body re-runs on
        // every `queue.currentProgress` tick while *this* game is analyzing,
        // and `pgnText` rebuilds the whole export string each pass.
        CollapsibleSection(.pgn, title: "PGN") {
            rawPGNText
        } actions: {
            copyPGNButton
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
    
    // `disclosureButton` lived here until D45′ and is now
    // `InspectorSectionHeader`'s own, along with its identifier. Its doc
    // reserved the rotated-chevron glyph "to keep consistent if a second
    // collapsible section ever wants the same control" — nine of them do, so
    // the reservation was honoured by moving the control rather than copying
    // it. The one thing that did not survive the move is its stated *order*:
    // that doc claimed the chevron sat leading of the copy button, and the
    // `HStack` put it trailing. The shared header implements what the comment
    // said, which changes this section's pixels — the copy glyph and the
    // chevron swap places.
    
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
    .environment(InspectorSectionCollapse.preview)
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
    .environment(InspectorSectionCollapse.preview)
}

#Preview("Empty") {
    LibraryInspectorView(queue: AnalysisQueueController())
        .frame(width: 300, height:700)
        .environment(InspectorSectionCollapse.preview)
}

/// The counting branch: nil `pgn` with a plural count — what a rubber-band
/// or ⌘-click selection shows. No fixture reaches this by accident, which
/// is the reason it has a preview.
#Preview("Multi-Selection") {
    LibraryInspectorView(selectionCount: 12, queue: AnalysisQueueController())
        .frame(width: 300, height: 700)
        .environment(InspectorSectionCollapse.preview)
}

/// The raw-PGN section against a game that actually has movetext — the other
/// three previews carry none, so the section renders a tag block over an
/// empty body in all of them. An odd ply count is the case worth seeing: the
/// serializer's white-only final line (`4. Qxf7#`), with the mate suffix
/// emitted verbatim.
///
/// The section starts **open**, as it does in the app; the canvas is live, so
/// folding it is a click.
///
/// This line said "starts collapsed" until D45′ — true when it was written and
/// wrong from 30 July, when Bera reversed the M1 collapsed default. Nothing
/// contradicted it, because a preview's prose is the least-read text in the
/// project and the canvas beside it was showing the opposite the whole time.
/// Note it is now *doubly* current-tense: the state is shared and persisted, so
/// what this preview starts as depends on the `preview` suite rather than on a
/// fresh `@State`.
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
    .environment(InspectorSectionCollapse.preview)
}
