import AppKit
import SwiftData
import SwiftUI

struct LibraryInspectorView: View {
    
    // MARK: Stored Properties
    let pgn: PGN?
    
    /// Selection count: `pgn` arrives nil for empty *and* multiple, so without this the view cannot
    /// tell "select something" from "you selected twelve".
    let selectionCount: Int

    // MARK: Initializers
    init(
        pgn: PGN? = nil,
        selectionCount: Int = 0
    ) {
        self.pgn = pgn
        self.selectionCount = selectionCount
    }
    
    // MARK: Body
    var body: some View {
        // The empty branch renders *outside* the `List`; inside one it is a top-aligned row with
        // sidebar chrome behind it.
        if let pgn {
            List {
                // .id re-inits per selected game, resetting per-game view state. It no longer tears down an
                // analysis — the queue outlives any one selection.
                LoadedSection(pgn: pgn)
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
    
    /// The counting variant: same shared chrome, same symbol as the columns detail pane — two
    /// surfaces, one vocabulary for "you selected many".
    private var multiSelectionState: some View {
        InspectorEmptyState(
            title: "\(selectionCount) Games Selected",
            systemImage: "document.on.document.fill",
            message: "Right-click any selected game to analyze, export or delete the whole selection.",
            identifier: AccessibilityID.libraryInspectorMulti
        )
    }
}

private struct LoadedSection: View {
    
    // MARK: Stored Properties
    @Bindable var pgn: PGN
    
    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut

    // MARK: Body
    var body: some View {
        Group {

            // The seven tags as one object, under the game's own name (the one thing the rows can't say).
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
    

    // MARK: Evaluation Section
    @ViewBuilder
    private var evaluationSection: some View {
        // The Review and Analyze row is gone (M10, by request); `reviewGlyphButton` in the roster header
        // is the fold-proof replacement.
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
            // Two controls in the slot (`actionsInset` spaces them). Data before the magnifier so the graph
            // control keeps the position a reader's hand learned.
            AnalysisDataButton(gameID: pgn.persistentModelID)
            EvaluationMagnifierButton(gameID: pgn.persistentModelID)
        }
    }
    
    // MARK: PGN Section
    
    /// The game as a file: `PGN.pgnText`, byte-identical to Export — an inspector formatting
    /// its own tag block would be a third PGN shape, free to drift from the reference bytes.
    private var pgnSection: some View {
        // `CollapsibleSection` gates the rebuild: body re-runs on every progress tick while this game
        // analyzes, and `pgnText` rebuilds the whole export string each pass.
        CollapsibleSection(.pgn, title: "PGN") {
            rawPGNText
        } actions: {
            // Read-only — the movetext door is Get Info's Move Text tab.
            copyPGNButton
        }
    }
    
    /// The bytes, extracted so the section body reads as the decision — open or not.
    private var rawPGNText: some View {
        Text(pgn.pgnText)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
        // A `List` row proposes a height and a multi-line `Text` collapses to one truncated line;
        // `fixedSize(vertical:)` takes the ideal height. Vertical only.
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(AccessibilityID.libraryInspectorPGN)
    }
    
    /// Review as a roster-header glyph — reachable while the Evaluation section is folded.
    /// Not an `InspectorEditButtonView` (that type hardcodes the pencil on purpose); shares the
    /// pair that must not drift: `.font(.body)`, one label feeding `.help` and `.accessibilityLabel`.
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

    /// Exported bytes to the pasteboard — in the header so it works while the section is collapsed.
    /// Not an `InspectorEditButtonView` (pencil-only by design); extract only if a second copy appears.
    private var copyPGNButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pgn.pgnText, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.borderless)
        // A glyph at header font size is an ~11 pt mouse target.
        .font(.body)
        .help("Copy PGN")
        .accessibilityLabel("Copy PGN")
        .accessibilityIdentifier(AccessibilityID.libraryInspectorCopyPGN)
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
    )
    .frame(width: 300, height: 700)
    .environment(InspectorSectionCollapse.preview)
}

#Preview("Empty") {
    LibraryInspectorView()
        .frame(width: 300, height:700)
        .environment(InspectorSectionCollapse.preview)
}

/// The counting branch — no fixture reaches it by accident, which is why it has a preview.
#Preview("Multi-Selection") {
    LibraryInspectorView(selectionCount: 12)
        .frame(width: 300, height: 700)
        .environment(InspectorSectionCollapse.preview)
}

/// The raw-PGN section over real movetext (the other previews carry none). Odd ply count on
/// purpose: the serializer's white-only final line, mate suffix intact.
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
    )
    .frame(width: 320, height:700)
    .environment(InspectorSectionCollapse.preview)
}
