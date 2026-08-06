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

    // `onEditMoves` was here until 5 Aug 2026 — an optional closure the
    // destination filled to draw the PGN header's Edit Moves pencil. It is
    // gone with the pencil: the movetext door is Get Info's Move Text tab, and
    // a closure nothing calls is the thing D54′ was itself written to stop.
    //
    // It outlived `BoardInspectorView.onEditInfo`, the precedent it cited, by
    // one day. Both were the same shape — a *host capability* expressed as an
    // optional closure, so an affordance that cannot act does not draw rather
    // than sitting greyed out (D40′ applied at minting) — and both ended the
    // same way, by the verb moving into Get Info. The pattern was sound; what
    // it turned out to be describing was a surface in transit.

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

    // `isNameFieldFocused`, `isEditingName` and `draftName` went with the
    // rename feature (M10) — see `body`.

    // MARK: Body
    var body: some View {
        Group {
            // `identitySection` lived here and is gone with the rename it
            // existed for. It was a `Section` with no header, empty except
            // while a rename was in progress — D45′ records that as the one
            // section deliberately not collapsible, "a chevron for hiding
            // something already invisible". With the editor gone it was a
            // section that was invisible always.

            // D22′ — the seven tags as one object, under the game's own name.
            // "Game Details" labelled what the rows already say they are; the
            // name is the one thing the section couldn't tell you.
            //
            // The actions slot is empty now. The pencil here renamed
            // `PGN.name` — the Library's *display* name, outside the content
            // hash and outside what export writes — which made it the odd one
            // of the five: the other four edit interchange truth. Removed
            // whole rather than folded into Get Info, by request: the default
            // name is derived from the seats (`PGN.defaultName`), and a
            // hand-typed override is a second naming rule beside D23′'s
            // one-way transform, which is the thing D23′ exists to refuse.
            SevenTagRosterSection(
                roster: RosterSummary(pgn),
                headline: pgn.name
            ) {
                reviewGlyphButton
            }

            OpeningSection(opening: pgn.opening)
            evaluationSection
            pgnSection
        }
    }
    
    
    // `reviewButton` was here until 6 Aug 2026. M10 removed the Review and
    // Analyze row that rendered it (see `evaluationSection`) and left the
    // implementation behind; `reviewGlyphButton` in the roster header is the
    // affordance that replaced it. Deleted by the between-milestone sweep,
    // with `analysisControlRow` and `hasRecordedAnalysis` below.

    // MARK: Evaluation Section
    @ViewBuilder
    private var evaluationSection: some View {
        // The Review and Analyze row that used to sit under the graph is gone
        // (M10, by request). D45′ recorded its presence here as an accepted
        // cost — collapsing this section hid both controls — and rejected
        // promoting them "because it would put two more glyphs beside a
        // chevron". Removing them settles that differently: Review is a glyph
        // in the roster header now, and Analyze is reachable from the Library
        // toolbar and every row's context menu, which is where a verb that
        // takes a *selection* belongs anyway.
        //
        // What went with the row and is not replaced here: the queue's
        // per-ply progress, Skip, and a failure's Retry, all four shapes of
        // `analysisControlRow`. The row's own state is still visible per game
        // through `AnalysisGlyph`, and the toolbar's popover owns the queue.
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
        } actions: {
            EvaluationMagnifierButton(gameID: pgn.persistentModelID)
        }
    }
    
    // `analysisControlRow` and `hasRecordedAnalysis` were here until 6 Aug
    // 2026, deleted together by the between-milestone sweep.
    //
    // The row rendered four shapes off the queue — enqueue, queued-with-a-way-
    // out, running-with-progress-and-skip, and failed-with-retry — and M10
    // removed the affordance that showed it, by request. `evaluationSection`
    // above has recorded that removal correctly since the day it happened; what
    // nobody noticed is that the *implementation* stayed, fully written and
    // rendered by nothing, for two months.
    //
    // `hasRecordedAnalysis` had exactly one caller, inside the row, so it went
    // with it. `AnalysisLabel`, `skipCurrent` and `removeWaiting` all have live
    // consumers elsewhere and stayed — checked rather than assumed.
    //
    // Why three sweeps missed it: the previous declaration scans counted a name
    // mentioned in a *comment* as a reference, and both names were mentioned in
    // the comment explaining their own removal. Stripping comments before
    // building the frequency table is what surfaced them.
    
    // MARK: PGN Section
    
    /// The game as a file: `PGN.pgnText`, byte-identical to what Export
    /// writes (D24′). Deliberately not its own rendering of the model — an
    /// inspector that formatted its own tag block would be a third PGN shape
    /// in the app, free to drift from the one the reference files pin, and
    /// the entire value of showing raw text is that it is what the file will
    /// say. Side effect worth having: a serializer defect is now visible in
    /// the sidebar instead of only in an exported file nobody re-reads.
    ///
    /// Last, and **open by default** — reversed 30 July from the M1 collapsed
    /// default: with the raw text a glance away, visible beat protecting the
    /// first screenful. The chevron earns its place in the other direction,
    /// hiding the longest section when it is in the way.
    ///
    /// The collapse is a plain `if`, not `Section(isExpanded:)`: the platform
    /// control only appears on hover, and a section whose one affordance is
    /// invisible until the pointer crosses it reads as a truncated line of text
    /// — which is exactly how this one read. Since D45′ that argument is the
    /// app's rather than this section's, `InspectorSectionHeader` drawing the
    /// chevron everywhere.
    ///
    /// Expansion **no longer resets per game** — D45′'s one behaviour change
    /// here, and the price of one collapse mechanism instead of two. The old
    /// flag was `@State` under `LoadedSection`'s `.id(pgn.id)` and reset on
    /// every selection; the shared store is app-wide and persisted, so a folded
    /// PGN section stays folded across games and launches.
    private var pgnSection: some View {
        // `CollapsibleSection` does the gating the ternary used to, which still
        // matters for the reason it always did: this view's body re-runs on
        // every `queue.currentProgress` tick while *this* game is analyzing,
        // and `pgnText` rebuilds the whole export string each pass.
        CollapsibleSection(.pgn, title: "PGN") {
            rawPGNText
        } actions: {
            // **The Edit Moves pencil stood here for one day** (D54′, 4 Aug)
            // and is gone (5 Aug): the movetext door is Get Info's Move Text
            // tab now. This section is read-only and renders the bytes, which
            // is what it was doing before D54′ put a pencil on it.
            //
            // Recorded rather than quietly reverted, because the argument that
            // put it here was good and is *still* good — a pencil belongs
            // adjacent to its subject, and this section renders the movetext.
            // What outranked it is that the pencil opened a modal over a
            // sidebar, while Get Info is a window that already edits this
            // game's other nine fields. Editing a game's Event in one place
            // and its moves in another was the split; one window that edits
            // everything about a game is the resolution, and the price is that
            // the editor is no longer adjacent to a rendering of its subject.
            //
            // The header is back to chevron + Copy, its pre-D54′ arity — which
            // is why `InspectorSectionHeader`'s *Actions — Every Arity*
            // preview still covers this slot without change.
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
    
    /// Review, as a glyph in the roster header — the same action as
    /// `reviewButton` in the Evaluation section body, reachable while that
    /// section is folded.
    ///
    /// **D45′'s recorded cost, paid.** That decision noted collapsing Evaluation
    /// also hides Review and Analyze, and rejected promoting them "because it
    /// would put two more glyphs beside a chevron". Two things changed: the
    /// promotion is to a *different* header — the roster, the section actually
    /// about the game — and that header's actions slot emptied when M10 removed
    /// the rename pencil. So it crowds nothing, which was the whole objection.
    ///
    /// **Not an `InspectorEditButtonView`**, for that type's own reason: it
    /// hardcodes the pencil so the remaining edit affordances cannot drift, and
    /// widening it to take a symbol would make it a generic icon button. The
    /// fourth open-coded glyph beside Copy-PGN and the magnifier, sharing the
    /// pair that must not drift — `.font(.body)`, and one label feeding both
    /// `.help` and `.accessibilityLabel`.
    private var reviewGlyphButton: some View {
        Button {
            openWindow(value: pgn.persistentModelID)
        } label: {
            Image(systemName: "play.fill")
        }
        .buttonStyle(.borderless)
        .font(.body)
        .help("Review this game in a new window")
        .accessibilityLabel("Review")
        .accessibilityIdentifier(AccessibilityID.libraryInspectorReviewGlyph)
    }

    /// Puts the exported bytes on the pasteboard, so a game reaches a mail draft
    /// or an analysis site without a round trip through the filesystem. In the
    /// header rather than beside the text, so it works while the section is
    /// collapsed.
    ///
    /// `NSPasteboard` because SwiftUI has no pasteboard-write API a button
    /// action can call: `.copyable(_:)` routes through the system Copy command
    /// and needs the view focused, which a sidebar section header cannot
    /// promise. Not an `InspectorEditButtonView`, for that type's reason —
    /// extract only if a second copy affordance appears.
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
    
    // `nameEditor`, `beginEdit()` and `commitEdit()` are gone with the rename
    // feature (M10). Worth one line on what left with them: `commitEdit` wrote
    // `pgn.name` straight through the model with no `PGNStore` door and no
    // `refreshHash` — correct, because `name` is outside the content hash, and
    // the *only* write in this file that was. It was also the app's one edit
    // that never passed through a store door, which is the shape the
    // invariants call out; nothing here needs re-homing because the write no
    // longer exists.
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
