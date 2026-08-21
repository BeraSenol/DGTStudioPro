import SwiftData
import SwiftUI

/// The magnifier's request. **The wrapper is the whole reason this type exists**:
/// `openWindow(value:)` routes by type, and the main group already claims `PersistentIdentifier`
/// - a second group over it would make every existing call unspecified.
struct EvaluationGraphRequest: Codable, Hashable, Sendable {

    let gameID: PersistentIdentifier

    init(gameID: PersistentIdentifier) {
        self.gameID = gameID
    }
}

/// The evaluation graph at full size with a pointer read-out. A window, not a popover or
/// sheet - field-tested, not argued: the popover was built and reverted in one day (dismisses on
/// the first board click, killing the companion-while-scrubbing use). Hover read-outs are what
/// 100 pt in a sidebar cannot afford - bigger makes a different question askable.
struct EvaluationGraphWindow: View {

    // MARK: Static Constants

    /// Matches the inspector graph's inset so the two read as one object at two sizes.
    private static let contentPadding: CGFloat = 20

    // MARK: Stored Properties
    let request: EvaluationGraphRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut

    /// Resolved once per request - a store lookup does not belong on a render path; the pointer
    /// lives inside `EvaluationGraphContent`.
    @State private var pgn: PGN?

    // MARK: Body
    var body: some View {
        Group {
            // `hasScoredPly`, not `!evaluations.isEmpty`: an all-nil array passed the old gate and the
            // `?? 0.5` map drew a flat midline curve instead of the empty state below.
            if let pgn, pgn.hasScoredPly {
                graph(for: pgn)
            } else {
                unavailable
            }
        }
        .padding(Self.contentPadding)
        .frame(minWidth: 480, minHeight: 300)
        .navigationTitle(pgn?.name ?? "Evaluation")
        .task(id: request) { resolve() }
    }

    // MARK: Instance Methods

    /// Cast paired with `isDeleted`, per the standing invariant - `model(for:)` hands back
    /// tombstones, and every property read on one traps.
    private func resolve() {
        guard let request,
              let model = modelContext.model(for: request.gameID) as? PGN,
              !model.isDeleted else {
            pgn = nil
            return
        }
        pgn = model
    }

    private func graph(for pgn: PGN) -> some View {
        // The curve maps *here*, once per resolved game - not per pointer move.
        EvaluationGraphContent(
            moves: pgn.moves,
            evaluations: pgn.evaluations,
            curve: pgn.winProbabilityCurve,
            style: boardStyle
        )
    }

    /// Two causes, one state: gone, or never analysed. Splitting would explain a deletion the
    /// reader performed; the remedy is identical.
    private var unavailable: some View {
        InspectorEmptyState(
            title: "No Analysis",
            systemImage: "chart.line.uptrend.xyaxis",
            message: "This game has no recorded evaluations, or it is no longer in the Library.",
            identifier: AccessibilityID.evaluationWindowEmpty
        )
    }
}

// MARK: Graph Content

/// Graph + read-out, split from the window so the pointer invalidates only this subtree -
/// `hoveredPly` as window `@State` re-ran the whole body per mouse move, including the curve map.
private struct EvaluationGraphContent: View {

    // MARK: Stored Properties
    let moves: [String]
    let evaluations: [Evaluation?]
    let curve: [Double]
    let style: BoardStyle

    @State private var hoveredPly: Int?

    // MARK: Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            readout
            graph
        }
    }

    /// Above the graph in a fixed-height slot: below, the cursor would sit on the answer; an
    /// appearing/vanishing read-out makes the layout jump on hover.
    private var readout: some View {
        let reading = hoveredPly.flatMap {
            EvaluationGraphReading(
                ply: $0,
                moves: moves,
                evaluations: evaluations
            )
        }
        return HStack(spacing: 12) {
            Text(reading?.move ?? RosterSummary.displayUnknown)
                .font(.system(.title3, design: .monospaced))
            if let reading {
                Text(reading.evaluation)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(moves.count) plies")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .frame(height: 24)
        .accessibilityIdentifier(AccessibilityID.evaluationWindowReadout)
    }

    private var graph: some View {
        GeometryReader { proxy in
            EvaluationGraphView(
                evaluations: curve,
                currentMoveIndex: hoveredPly,
                style: style
            )
            // `.onContinuousHover`: the question is *where*, which `onHover`'s Bool cannot answer. The
            // ended case clears - a stale ply describes nothing.
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    hoveredPly = EvaluationGraphGeometry(
                        width: proxy.size.width,
                        plyCount: curve.count
                    )
                    .ply(nearestTo: location.x)
                case .ended:
                    hoveredPly = nil
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.evaluationWindowGraph)
    }
}

// MARK: Magnifier

/// The header control that opens the window, both Evaluation sections. (Tried as a popover
/// for a day; reverted.) Not an `InspectorEditButtonView`
/// - that hardcodes the pencil on purpose; shares only `.font(.body)` + one label for both
/// `.help` and `.accessibilityLabel`.
struct EvaluationMagnifierButton: View {

    // MARK: Stored Properties
    let gameID: PersistentIdentifier

    // MARK: Private Properties
    @Environment(\.openWindow) private var openWindow

    // MARK: Body
    var body: some View {
        Button {
            openWindow(value: EvaluationGraphRequest(gameID: gameID))
        } label: {
            Image(systemName: "magnifyingglass")
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .font(.body)
        .help("Open the evaluation graph in its own window")
        .accessibilityLabel("Open the evaluation graph in its own window")
        .accessibilityIdentifier(AccessibilityID.evaluationMagnifier)
    }
}

// MARK: Previews

/// Both read-out states need a pointer, so a canvas cannot reach them; this pins the empty
/// branch and the populated layout (all-nil evaluations, deliberately).
#Preview("No Analysis") {
    EvaluationGraphWindow(request: nil)
        .frame(width: 620, height: 380)
        .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Content, Curve") {
    EvaluationGraphContent(
        moves: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"],
        evaluations: [Evaluation?](repeating: nil, count: 6),
        curve: [0.5, 0.55, 0.52, 0.61, 0.58, 0.64],
        style: .walnut
    )
    .padding(20)
    .frame(width: 620, height: 380)
}
