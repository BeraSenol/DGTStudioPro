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
/// That paragraph is no longer only an argument: on 4 Aug 2026 the popover
/// was built and lived for part of a day — Library first, then both hosts —
/// and the window returned the same night. The dismiss-on-step price read
/// fine on paper and was not livable in use, which is the strongest
/// justification this decision will ever have. The anchor records the round
/// trip; what the day-trip paid for stayed (`EvaluationGraphContent`, cut to
/// scope pointer invalidation, renders this window's body).
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

    /// Resolved once per request rather than computed in `body` — a store
    /// lookup does not belong on a render path, and the pointer lives inside
    /// `EvaluationGraphContent`, so this body re-runs only when the request
    /// or the resolved game changes.
    @State private var pgn: PGN?

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
        // The curve maps *here*, once per resolved game — not per pointer
        // move. `EvaluationGraphContent` owns the pointer; see its doc.
        EvaluationGraphContent(
            moves: pgn.moves,
            evaluations: pgn.evaluations,
            curve: pgn.evaluations.map { $0?.whiteWinProbability ?? 0.5 },
            style: boardStyle
        )
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

// MARK: Graph Content

/// The graph plus its hover read-out, split from the window so the pointer
/// invalidates only this subtree (4 Aug 2026). `hoveredPly` used to be
/// `@State` on the window, which made every mouse movement re-run the whole
/// window body — including the `evaluations.map` feeding the curve, the cost
/// the 1 Aug review's P3 note called out as beneath this file's own standard
/// (its resolve doc had hoisted the *store lookup* off the pointer for
/// exactly this reason). The parent maps once per resolved game; the pointer
/// touches nothing above this struct.
///
/// Takes `evaluations` *and* the pre-mapped `curve` rather than re-deriving
/// one from the other: the read-out needs the real `Evaluation?`s (its label
/// speaks the pinned mate grammar), the graph needs the folded fractions,
/// and mapping here would put the work right back on the pointer's path.
///
/// One host: the window's body. (It briefly served a popover on 4 Aug 2026 —
/// both presentations, one reading, which is what made the same-night
/// reversal a call-site change rather than a rebuild. The extraction itself
/// predates that day-trip: it was cut to scope pointer invalidation, and
/// that reason stands on its own.)
private struct EvaluationGraphContent: View {

    // MARK: Stored Properties
    internal let moves: [String]
    internal let evaluations: [Evaluation?]
    internal let curve: [Double]
    internal let style: BoardStyle

    @State private var hoveredPly: Int?

    // MARK: Body
    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            readout
            graph
        }
    }

    /// Above the graph, not below it, and in a fixed-height slot: the pointer
    /// is *on* the curve while reading this, so putting the text under the
    /// pointer's own path would have the cursor sitting on the answer. The
    /// fixed slot is the `EvaluationBarView` label's rule — a read-out that
    /// appears and disappears makes the layout jump on hover, which is motion
    /// the eye follows instead of the curve.
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

/// The header control that opens the window, in both Evaluation sections.
/// (It spent part of 4 Aug 2026 as a popover — split by host, then both
/// hosts, then reverted the same night; the D46′ anchor carries the round
/// trip and the field-tested reason the window won.)
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
/// reachable in a canvas: both need a pointer. What a preview *can* pin is
/// the empty branch — the one a reader hits by accident, opening the
/// magnifier on an unanalysed game — plus the content's populated layout,
/// kept from the popover day-trip because it witnesses `EvaluationGraphContent`
/// regardless of who presents it. All-nil evaluations are deliberate there:
/// the curve draws from the pre-mapped values, so no fixture has to guess an
/// `Evaluation` initializer to witness layout.
#Preview("No Analysis") {
    EvaluationGraphWindow(request: nil)
        .frame(width: 620, height: 380)
        .modelContainer(for: PGN.self, inMemory: true)
}

#Preview("Content — Curve") {
    EvaluationGraphContent(
        moves: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"],
        evaluations: [Evaluation?](repeating: nil, count: 6),
        curve: [0.5, 0.55, 0.52, 0.61, 0.58, 0.64],
        style: .walnut
    )
    .padding(20)
    .frame(width: 620, height: 380)
}
