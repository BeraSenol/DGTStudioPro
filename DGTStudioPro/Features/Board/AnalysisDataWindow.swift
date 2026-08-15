import SwiftData
import SwiftUI

/// The data button's request — the fourth `openWindow(value:)` wrapper, for the standing
/// reason: the call routes by type.
struct AnalysisDataRequest: Codable, Hashable, Sendable {

    let gameID: PersistentIdentifier

    init(gameID: PersistentIdentifier) {
        self.gameID = gameID
    }
}

/// One ply of the table, as values (suite-testable, D10′). Move grammar is
/// `EvaluationGraphReading`'s; evaluation is `EvaluationBarReading`'s pinned grammar — but
/// **nil for an unscored ply**, deliberately unlike the display surfaces: this table is stored
/// truth, and `0.0` for a never-scored ply would be a lie.
struct AnalysisDataRow: Equatable, Sendable, Identifiable {

    /// 0-based ply — the array position, unique by construction.
    let ply: Int
    /// "12. Nf3" / "12… Nf6".
    let move: String
    /// The bar-grammar label ("+1.3", "0.0", "#4"), or nil for an unscored ply.
    let evaluation: String?
    /// "64%" — white's win probability, or nil with `evaluation`.
    let whiteWinPercent: String?
    /// Signed win-probability swing vs. the ply before, in percentage points — "+12" / "-31" —
    /// or nil when either side of the step is unscored: no fake deltas across book gaps (D77′).
    /// White-relative, like every number on this surface; the blunder signal is the magnitude.
    let swing: String?
    /// |swing| ≥ 15 pp — the emphasis threshold, a judgement call documented as one (D77′).
    let swingIsMajor: Bool

    var id: Int { ply }

    /// The whole table; tolerates both invariant shapes of `evaluations` — an index past the end is
    /// an unscored ply, not a crash.
    static func rows(
        moves: [String],
        evaluations: [Evaluation?]
    ) -> [AnalysisDataRow] {
        moves.indices.map { ply in
            let evaluation = ply < evaluations.count ? evaluations[ply] : nil
            let previous = ply > 0 && ply - 1 < evaluations.count ? evaluations[ply - 1] : nil
            let delta: Double? = {
                guard let evaluation, let previous else { return nil }
                return (evaluation.whiteWinProbability - previous.whiteWinProbability) * 100
            }()
            return AnalysisDataRow(
                ply: ply,
                move: EvaluationGraphReading(
                    ply: ply, moves: moves, evaluations: evaluations
                )?.move ?? moves[ply],
                evaluation: evaluation.map { EvaluationBarReading($0).label },
                whiteWinPercent: evaluation.map {
                    "\(Int(($0.whiteWinProbability * 100).rounded()))%"
                },
                swing: delta.map { d in
                    let points = Int(d.rounded())
                    return points >= 0 ? "+\(points)" : "\(points)"
                },
                swingIsMajor: delta.map { abs($0) >= 15 } ?? false
            )
        }
    }
}

/// D73′ — the analysis as data, every ply in its own window. A window (companion surface), its
/// own group (data windows tab with each other, never boards); deliberately not floating,
/// unlike the graph — a table is consulted, not glanced.
struct AnalysisDataWindow: View {

    // MARK: Stored Properties
    let request: AnalysisDataRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext

    /// Resolved once per request — a store lookup does not belong on a render path.
    @State private var pgn: PGN?

    // MARK: Body
    var body: some View {
        Group {
            // `hasScoredPly` (D67′): an all-nil array is a table of em dashes wearing the shape of data.
            // The rows tolerate partial arrays; the gate refuses empty ones.
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

    /// Blessed cast + tombstone check, per the standing invariant.
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
        // Per resolved game, not per render tick — a pure fold over stored values.
        let rows = AnalysisDataRow.rows(moves: pgn.moves, evaluations: pgn.evaluations)
        return Table(rows) {
            TableColumn("Move") { row in
                Text(row.move)
                    .font(.body.monospaced())
            }
            .width(min: 90, ideal: 110)
            // The house em dash for an unscored ply, secondary so gaps read as absences.
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
            // D77′ — the blunder signal, from data the app already stored. Emphasis by weight, not
            // colour: the sign is white-relative, so red-means-bad would lie for one side.
            TableColumn("Swing") { row in
                Text(row.swing ?? RosterSummary.displayUnknown)
                    .monospacedDigit()
                    .fontWeight(row.swingIsMajor ? .semibold : .regular)
                    .foregroundStyle(row.swingIsMajor ? .primary : .secondary)
            }
            .width(min: 52, ideal: 60)
        }
        .accessibilityIdentifier(AccessibilityID.analysisDataWindowTable)
    }

    /// Two causes, one state — the graph window's fold, for its reason.
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

/// The magnifier's sibling in the Evaluation header — fourth open-coded glyph button; shares
/// only the pair that must not drift (`.font(.body)`, one label for `.help` + AX).
struct AnalysisDataButton: View {

    // MARK: Stored Properties
    let gameID: PersistentIdentifier

    // MARK: Private Properties
    @Environment(\.openWindow) private var openWindow

    // MARK: Body
    var body: some View {
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

/// The empty branch — pressing the button on a game skipped before it scored anything.
#Preview("No Analysis") {
    AnalysisDataWindow(request: nil)
        .frame(width: 460, height: 400)
        .modelContainer(for: PGN.self, inMemory: true)
}

/// The populated table; the partial array is the canonical fixture (rows 4–5 must read as
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
