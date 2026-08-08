import SwiftData
import SwiftUI

/// What the data button asks for: one game's evaluations, as numbers.
///
/// The fourth wrapper in the `openWindow(value:)` family, for the reason the
/// first three exist (D46′, D53′): the call routes by the value's *type*, the
/// main `WindowGroup` claims `PersistentIdentifier`, and a second group over
/// it would leave every existing call unspecified. The queue and View Options
/// windows sidestepped this by being singletons opened by `id`; this one has a
/// subject, so it pays the wrapper like the graph does.
internal struct AnalysisDataRequest: Codable, Hashable, Sendable {

    internal let gameID: PersistentIdentifier

    internal init(gameID: PersistentIdentifier) {
        self.gameID = gameID
    }
}

/// One ply of the table: the move, and what the engine thought — as values,
/// so the fold is suite-testable without a container (D10′'s posture).
///
/// **The move grammar is `EvaluationGraphReading`'s, reused rather than
/// restated** — "12. Nf3" / "12… Nf6", the app's one spelling of a lone ply.
/// The evaluation label is `EvaluationBarReading`'s pinned grammar for the
/// same reason (D33′).
///
/// **`evaluation` is optional where the graph's reading folds nil to "0.0",
/// and the difference is deliberate, not drift.** The bar and the hover
/// read-out are *display* surfaces that must render something at every ply,
/// so their nil rule folds to `.drawn`. A data table's whole promise is the
/// stored truth, and printing `0.0` for a ply the engine never scored would
/// manufacture the exact false reading D67′ was minted against — so an
/// unscored ply carries nil here and the window renders the house em dash.
internal struct AnalysisDataRow: Equatable, Sendable, Identifiable {

    /// 0-based ply index — the array position, unique by construction.
    internal let ply: Int
    /// "12. Nf3" / "12… Nf6".
    internal let move: String
    /// The bar-grammar label ("+1.3", "0.0", "#4"), or nil for an unscored ply.
    internal let evaluation: String?
    /// "64%" — white's win probability, or nil with `evaluation`.
    internal let whiteWinPercent: String?

    internal var id: Int { ply }

    /// The whole table from the stored pair. Tolerates the two invariant
    /// shapes of `evaluations` (empty, or parallel to `moves`) the way
    /// `PGN.evaluation(atPly:)` does — an index past the array's end is an
    /// unscored ply, not a crash.
    internal static func rows(
        moves: [String],
        evaluations: [Evaluation?]
    ) -> [AnalysisDataRow] {
        moves.indices.map { ply in
            let evaluation = ply < evaluations.count ? evaluations[ply] : nil
            return AnalysisDataRow(
                ply: ply,
                move: EvaluationGraphReading(
                    ply: ply, moves: moves, evaluations: evaluations
                )?.move ?? moves[ply],
                evaluation: evaluation.map { EvaluationBarReading($0).label },
                whiteWinPercent: evaluation.map {
                    "\(Int(($0.whiteWinProbability * 100).rounded()))%"
                }
            )
        }
    }
}

/// D73′ — the analysis as data: every ply, its move, the engine's number and
/// the win probability it projects, in a window of its own.
///
/// **A window, not a sheet or a fourth inspector section**, for the graph
/// window's field-tested reason: the numbers are read *against* something —
/// the curve, the board, a scoresheet — and a companion that dismisses on the
/// first outside click is not a companion. Its own group, so two games' data
/// windows tab with each other and never with the boards.
///
/// **Deliberately not `.windowLevel(.floating)`**, unlike the graph: the
/// graph is glanced at while the board underneath is driven, while a table of
/// a hundred rows is scrolled and text-selected — it takes focus, and the Get
/// Info argument applies (a floating window that owns the keyboard is the
/// shape people file bugs about).
internal struct AnalysisDataWindow: View {

    // MARK: Stored Properties
    internal let request: AnalysisDataRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext

    /// Resolved once per request — the graph window's arrangement, for its
    /// reason: a store lookup does not belong on a render path.
    @State private var pgn: PGN?

    // MARK: Body
    internal var body: some View {
        Group {
            // `hasScoredPly` (D67′): an all-nil array is a table of em dashes
            // wearing the shape of data, which is the exact false reading the
            // predicate exists to name. The rows tolerate partial arrays; the
            // gate refuses empty ones.
            if let pgn, pgn.hasScoredPly {
                table(for: pgn)
            } else {
                unavailable
            }
        }
        .frame(minWidth: 420, minHeight: 320)
        .navigationTitle(pgn.map { "Analysis — \($0.name)" } ?? "Analysis Data")
        .task(id: request) { resolve() }
    }

    // MARK: Instance Methods

    /// The blessed cast plus the `isDeleted` tombstone check, per the standing
    /// invariant — a game deleted while this window is open resolves to the
    /// unavailable state rather than a trap.
    private func resolve() {
        guard let request,
              let model = modelContext.model(for: request.gameID) as? PGN,
              !model.isDeleted else {
            pgn = nil
            return
        }
        pgn = model
    }

    private func table(for pgn: PGN) -> some View {
        // Built per resolved game, not per render tick: the rows are a pure
        // fold over stored values, and nothing in this window mutates them.
        let rows = AnalysisDataRow.rows(moves: pgn.moves, evaluations: pgn.evaluations)
        return Table(rows) {
            TableColumn("Move") { row in
                Text(row.move)
                    .font(.body.monospaced())
            }
            .width(min: 90, ideal: 110)
            // The house em dash for an unscored ply (D55′'s glyph), secondary
            // so the gaps read as absences rather than as small numbers.
            TableColumn("Evaluation") { row in
                Text(row.evaluation ?? RosterSummary.displayUnknown)
                    .monospacedDigit()
                    .foregroundStyle(row.evaluation == nil ? .secondary : .primary)
            }
            .width(min: 70, ideal: 90)
            TableColumn("White Win") { row in
                Text(row.whiteWinPercent ?? RosterSummary.displayUnknown)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 70, ideal: 90)
        }
        .accessibilityIdentifier(AccessibilityID.analysisDataWindowTable)
    }

    /// Two causes, one state — the graph window's fold, for its reason: the
    /// game is gone or was never analysed, and the remedy is the same.
    private var unavailable: some View {
        InspectorEmptyState(
            title: "No Analysis",
            systemImage: "tablecells",
            message: "This game has no recorded evaluations, or it is no longer in the library.",
            identifier: AccessibilityID.analysisDataWindowEmpty
        )
    }
}

// MARK: Header Button

/// The header control that opens the window — the magnifier's sibling, second
/// in the Library inspector's Evaluation header (8 Aug 2026, by request).
///
/// Fourth member of the open-coded glyph-button family
/// (`EvaluationMagnifierButton` carries the family's argument: extracting a
/// shared `IconButton` would collapse the distinction D26′ buys). It shares
/// the two things that must not drift — `.font(.body)`, and one string
/// feeding both `.help` and `.accessibilityLabel`.
internal struct AnalysisDataButton: View {

    // MARK: Stored Properties
    internal let gameID: PersistentIdentifier

    // MARK: Private Properties
    @Environment(\.openWindow) private var openWindow

    // MARK: Body
    internal var body: some View {
        Button {
            openWindow(value: AnalysisDataRequest(gameID: gameID))
        } label: {
            Image(systemName: "tablecells")
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .font(.body)
        .help("Open the analysis data in its own window")
        .accessibilityLabel("Open the analysis data in its own window")
        .accessibilityIdentifier(AccessibilityID.analysisDataButton)
    }
}

// MARK: Previews

/// The empty branch — the one a reader hits by accident, pressing the button
/// on a game whose analysis was skipped before it scored anything.
#Preview("No Analysis") {
    AnalysisDataWindow(request: nil)
        .frame(width: 460, height: 400)
        .modelContainer(for: PGN.self, inMemory: true)
}

/// The populated table, container round trip and all — the Get Info game
/// preview's argument: a heterogeneous layout is what a canvas is for, and
/// the partial array is the canonical fixture shape (rows 4–5 must read as
/// em-dash gaps, not zeros).
#Preview("Data") {
    let container = try! ModelContainer(
        for: PGN.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let pgn = PGN(
        white: "Senol, Bera",
        black: "Heylen, Christophe",
        moves: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"],
        evaluations: [
            .centipawns(31), .centipawns(18), .centipawns(45),
            nil, nil, .mate(4),
        ],
        result: .whiteWins
    )
    container.mainContext.insert(pgn)

    return AnalysisDataWindow(request: AnalysisDataRequest(gameID: pgn.persistentModelID))
        .frame(width: 460, height: 400)
        .modelContainer(container)
}
