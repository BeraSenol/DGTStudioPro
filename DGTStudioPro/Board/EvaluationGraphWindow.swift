//
//  EvaluationGraphWindow.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 01/08/2026.
//

import SwiftData
import SwiftUI

/// What the magnifier asks for: one game's evaluation curve, enlarged.
///
/// **A wrapper around a `PersistentIdentifier` rather than the identifier
/// itself, and that is the whole reason this type exists.** `openWindow(value:)`
/// routes by the value's *type*, and the app's main `WindowGroup` is already
/// declared `for: PersistentIdentifier.self` with three call sites relying on
/// it. A second group over the same type would make every one of those calls
/// ambiguous — at best unspecified, and unspecified in a way that shows up as
/// "opening a game from the Library now opens a graph".
///
/// So the routing is a fact about the type system rather than about scene
/// declaration order. The cost is one struct; the alternative was passing
/// `id:` at every call site and trusting that the untagged calls elsewhere
/// still resolve the way they used to.
internal struct EvaluationGraphRequest: Codable, Hashable, Sendable {

    internal let gameID: PersistentIdentifier

    internal init(gameID: PersistentIdentifier) {
        self.gameID = gameID
    }
}

/// M8 (D46′) — the evaluation graph at full size, in its own window, with a
/// read-out under the pointer.
///
/// **A window rather than a popover or a sheet**, chosen for what the enlarged
/// graph is actually *for*: reading the curve while stepping through the game
/// beside it. A popover dismisses the moment you click the board, and a sheet
/// takes the window over — both are right for "glance bigger, dismiss fast"
/// and both make the one use that needed more room impossible. The app already
/// opens games this way, so the gesture is not a new idea here.
///
/// **Hover read-outs are the affordance the small graph cannot afford.** A
/// 100 pt strip in a sidebar has no room to say which ply is which; at window
/// size the curve is legible enough that "which move was that?" becomes the
/// obvious next question. That is the whole argument for the feature — not
/// that bigger is better, but that bigger makes a different question askable.
internal struct EvaluationGraphWindow: View {

    // MARK: Static Constants

    /// Matches the inspector graph's own inset so the two read as the same
    /// object at two sizes.
    private static let contentPadding: CGFloat = 20

    // MARK: Stored Properties
    internal let request: EvaluationGraphRequest?

    // MARK: Private Properties
    @Environment(\.modelContext) private var modelContext
    @AppStorage(StorageKeys.boardStyle) private var boardStyle: BoardStyle = .walnut

    /// Resolved once per request rather than computed in `body`: `body` re-runs
    /// on every pointer move while hovering, and `model(for:)` on each of those
    /// would be a store lookup per mouse event.
    @State private var pgn: PGN?
    @State private var hoveredPly: Int?

    // MARK: Body
    internal var body: some View {
        Group {
            if let pgn, !pgn.evaluations.isEmpty {
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

    /// The cast is paired with an `isDeleted` check, per the standing
    /// invariant: `model(for:)` will happily hand back a tombstone for a game
    /// deleted while this window was open, and every property read on one
    /// traps. The window then shows its unavailable state, which is the honest
    /// answer — the game it was opened for is gone.
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
        VStack(alignment: .leading, spacing: 12) {
            readout(for: pgn)
            curve(for: pgn)
        }
    }

    /// Above the graph, not below it, and in a fixed-height slot: the pointer
    /// is *on* the curve while reading this, so putting the text under the
    /// pointer's own path would have the cursor sitting on the answer. The
    /// fixed slot is the `EvaluationBarView` label's rule — a read-out that
    /// appears and disappears makes the layout jump on hover, which is motion
    /// the eye follows instead of the curve.
    private func readout(for pgn: PGN) -> some View {
        let reading = hoveredPly.flatMap {
            EvaluationGraphReading(
                ply: $0,
                moves: pgn.moves,
                evaluations: pgn.evaluations
            )
        }
        return HStack(spacing: 12) {
            Text(reading?.move ?? "—")
                .font(.system(.title3, design: .monospaced))
            if let reading {
                Text(reading.evaluation)
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text("\(pgn.moves.count) plies")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .frame(height: 24)
        .accessibilityIdentifier(AccessibilityID.evaluationWindowReadout)
    }

    private func curve(for pgn: PGN) -> some View {
        GeometryReader { proxy in
            EvaluationGraphView(
                evaluations: pgn.evaluations.map {
                    $0?.whiteWinProbability ?? 0.5
                },
                currentMoveIndex: hoveredPly,
                style: boardStyle
            )
            // `.onContinuousHover` rather than `.onHover`: the question is
            // *where* the pointer is, which `onHover`'s bare Bool cannot
            // answer. The ended case clears the read-out — a stale ply left
            // on screen after the pointer leaves is a read-out describing
            // nothing.
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    hoveredPly = EvaluationGraphGeometry(
                        width: proxy.size.width,
                        plyCount: pgn.evaluations.count
                    )
                    .ply(nearestTo: location.x)
                case .ended:
                    hoveredPly = nil
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.evaluationWindowGraph)
    }

    /// Two causes, one state, deliberately: the game is gone, or it was never
    /// analysed. Splitting them would mean a window that explains a deletion
    /// the reader performed themselves, and the remedy is the same either way
    /// — close this and pick a game with analysis.
    private var unavailable: some View {
        InspectorEmptyState(
            title: "No Analysis",
            systemImage: "chart.line.uptrend.xyaxis",
            message: "This game has no recorded evaluations, or it is no longer in the library.",
            identifier: AccessibilityID.evaluationWindowEmpty
        )
    }
}

// MARK: Magnifier

/// The header control that opens the window, in both Evaluation sections.
///
/// **Not an `InspectorEditButtonView`**, and for that type's own stated reason:
/// it hardcodes the pencil precisely so three inspectors' edit affordances
/// cannot drift, and widening it to take a symbol would turn a named affordance
/// into a generic icon button. The Library's Copy-PGN button makes the same
/// argument and stays open-coded; this is the third member of that family, and
/// three is the point at which it is worth saying out loud that the family is
/// deliberate rather than neglected — extracting a shared `IconButton` now
/// would collapse exactly the distinction D26′ buys.
///
/// It does share the two things that must not drift: `.font(.body)` for the hit
/// target, and one `LocalizedStringKey` feeding both `.help` and
/// `.accessibilityLabel` so a glyph-only button never announces "magnifying
/// glass" to VoiceOver.
internal struct EvaluationMagnifierButton: View {

    // MARK: Stored Properties
    internal let gameID: PersistentIdentifier

    // MARK: Private Properties
    @Environment(\.openWindow) private var openWindow

    // MARK: Body
    internal var body: some View {
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

/// The read-out's two states are the thing worth seeing, and neither is
/// reachable in a canvas: both need a pointer. What a preview *can* pin is the
/// empty branch, which is the one a reader hits by accident — opening the
/// magnifier on an unanalysed game — and which no manual check will think to
/// perform.
#Preview("No Analysis") {
    EvaluationGraphWindow(request: nil)
        .frame(width: 620, height: 380)
        .modelContainer(for: PGN.self, inMemory: true)
}
