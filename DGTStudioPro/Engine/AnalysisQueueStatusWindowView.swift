import SwiftData
import SwiftUI

/// The analysis queue in full: what the engine is searching right now, how long
/// the batch has taken and roughly how long is left, everything still in line,
/// and everything already done with its outcome.
///
/// **Replaces `AnalysisQueueStatusView`, which was a toolbar popover** (6 Aug
/// 2026, by request). The popover is deleted rather than kept alongside: it
/// dismissed on the first click anywhere else, which is precisely the gesture a
/// reader makes while a batch runs — scroll the Library, open a game, keep
/// working. D46′ field-tested that exact trade on the evaluation graph across a
/// same-day round trip and reverted to a window; a queue that runs for minutes
/// is the stronger case of the two, so this takes the finding as settled rather
/// than re-testing it.
///
/// What the extra room bought, in the order it matters:
///
/// - **The running search**, live off the driver — depth, evaluation, speed and
///   which ply. A popover could not have held it and a progress bar could not
///   have said it.
/// - **Elapsed and a projection.** Measured and guessed respectively, and
///   spelled differently on purpose (`BatchProgressEstimate` argues the format).
/// - **The finished log, whole.** The popover listed failures only, so a
///   drained batch showed nothing about the games that worked.
/// - **No row cap.** The popover truncated at eight with "…and N more" because
///   a hundred rows do not belong in a popover. They belong in a scroll view.
///
/// Pure rendering over `AnalysisQueueController` — every mutation routes through
/// the controller, so the queue's decisions stay in one place. The window reads
/// it from the environment rather than taking it as a parameter, because a
/// scene's content cannot be handed a reference at the call site.
internal struct AnalysisQueueStatusWindowView: View {

    // MARK: Static Constants

    /// The scene id, spelled once. `openWindow(id:)` takes a bare `String` and
    /// a typo in it fails at *runtime* with a console warning and no window —
    /// the one failure mode a `Window` scene has that a value-routed
    /// `WindowGroup` does not, since those at least fail by type.
    internal static let sceneID = "analysis.queue"

    // MARK: Stored Properties

    @Environment(AnalysisQueueController.self) private var controller

    // MARK: Body

    internal var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let search = controller.currentSearch {
                    searchPanel(search)
                } else if controller.queue.current != nil {
                    // Between plies, and between the engine handshake and the
                    // first `info` line. A row of em dashes would flicker once
                    // per ply; naming the state holds the layout still.
                    Text("Waiting for the engine…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if !controller.queue.waiting.isEmpty { waitingSection }
                if !controller.queue.finished.isEmpty { finishedSection }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .accessibilityIdentifier(AccessibilityID.analysisQueueWindow)
    }

    // MARK: Header

    /// Title, counted position, and the two clocks.
    ///
    /// The timing row is wrapped in a `TimelineView` rather than driven by a
    /// published tick on the controller — a per-second write to an `@Observable`
    /// would invalidate every one of its observers once a second, and the only
    /// one that wants a second hand is this window. `.periodic` from the batch
    /// start so the seconds column turns over on the same boundary the elapsed
    /// figure does, instead of drifting against it.
    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerTitle)
                .font(.title2.weight(.semibold))

            if let started = controller.batchStartedAt {
                TimelineView(.periodic(from: started, by: 1)) { context in
                    Text(timingLine(now: context.date, started: started))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var headerTitle: String {
        let queue = controller.queue
        guard queue.isActive else {
            return queue.hasFailures ? "Analysis finished with errors" : "Analysis finished"
        }
        // "Analyzing 3 of 18" — `batchPosition` is the one spelling of that
        // numerator, shared with the Library toolbar's "3/18" so the two
        // surfaces cannot disagree by one the way they used to (8 Aug 2026;
        // the arithmetic and its clamp moved to the queue with the reason).
        return "Analyzing \(queue.batchPosition) of \(queue.totalCount)"
    }

    /// "4:12 elapsed · about 9 min left" — and only the half that is knowable.
    ///
    /// The projection drops off entirely once the queue drains, rather than
    /// reading "about 0 sec": a finished batch has no remainder, and an estimate
    /// of nothing is not the same statement as no estimate.
    private func timingLine(now: Date, started: Date) -> String {
        let elapsed = BatchProgressEstimate.describe(
            elapsed: now.timeIntervalSince(started)
        )
        guard controller.queue.isActive,
              let seconds = controller.secondsRemaining
        else { return "\(elapsed) elapsed" }
        return "\(elapsed) elapsed · \(BatchProgressEstimate.describe(secondsRemaining: seconds)) left"
    }

    // MARK: Running Search

    /// The game on the engine, its per-ply progress, and the search itself.
    ///
    /// The move is rendered in chess notation rather than as a ply ordinal —
    /// "12… Nf6", not "ply 24" — for the reason `GameAnalysisDriver.moveLabel`
    /// records: in a chess app a bare ordinal reads as a full-move number and
    /// points at the wrong move for every black ply.
    private func searchPanel(_ search: GameAnalysisDriver.Search) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AnalyzingGear()
                Text(controller.currentGameName ?? "Current game")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button("Skip", systemImage: "forward.end.fill") {
                    controller.skipCurrent()
                }
                .labelStyle(.titleAndIcon)
                .help("Stop this game and continue with the next")
                .accessibilityIdentifier(AccessibilityID.analysisQueueSkip)
            }

            ProgressView(value: controller.currentProgress)

            HStack(alignment: .top, spacing: 24) {
                searchFact("Move", moveLabel(search))
                // The *target*, not the live iteration (8 Aug 2026, by
                // request): `progress.depth` climbs 1→18 inside every ply and
                // resets at the next, so the readout spun constantly and read
                // as the depth *setting* bouncing. The argument and the kept
                // live figure are at `Search.targetDepth`.
                searchFact("Depth", "\(search.targetDepth)")
                // Through `EvaluationBarReading` rather than formatted here, so
                // this window and the board's bar cannot disagree about what
                // "+1.3" or "#4" looks like — D33′ pinned that grammar and
                // D46′'s graph window already reuses it, which makes this the
                // third consumer of one spelling rather than a new one.
                searchFact("Evaluation", EvaluationBarReading(search.progress.evaluation).label)
                searchFact("Speed", speedLabel(search.progress.nodesPerSecond))
            }
            .font(.callout)
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func searchFact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
    }

    private func moveLabel(_ search: GameAnalysisDriver.Search) -> String {
        let number = search.plyIndex / 2 + 1
        let separator = search.plyIndex.isMultiple(of: 2) ? ". " : "… "
        return "\(number)\(separator)\(search.san)"
    }

    /// "8.9 Mn/s" — meganodes per second, which is the unit every engine front
    /// end shows and the only one where a Stockfish figure fits in four
    /// characters. Below a million it degrades to thousands rather than
    /// printing "0.0".
    private func speedLabel(_ nodesPerSecond: Int?) -> String {
        guard let nodesPerSecond else { return RosterSummary.displayUnknown }
        if nodesPerSecond >= 1_000_000 {
            return String(format: "%.1f Mn/s", Double(nodesPerSecond) / 1_000_000)
        }
        return "\(nodesPerSecond / 1_000) kn/s"
    }

    // MARK: Lists

    /// Everything still in line, in the order it will run, with per-row removal.
    ///
    /// **No cap**, unlike the popover's eight. The rows are cheap and the window
    /// scrolls; "…and 92 more" was a popover's apology for being a popover.
    private var waitingSection: some View {
        section("Up Next", count: controller.queue.waiting.count) {
            ForEach(Array(controller.queue.waiting.enumerated()), id: \.element) { index, id in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 10, alignment: .leading)
                    Text(controller.displayName(for: id))
                        .lineLimit(1)
                    Spacer()
                    Text(plyLabel(for: id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button("Remove", systemImage: "xmark.circle") {
                        controller.removeWaiting(id)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Remove from the queue")
                }
            }
        }
    }

    /// Everything already done, newest first, each with what happened to it.
    ///
    /// **Newest first, unlike the queue's own storage**, which appends in
    /// completion order. A finished log read top-down during a live batch wants
    /// the thing that just happened at the top; `AnalysisQueue.finished` keeps
    /// completion order because that is what "in the order they finished" means
    /// for anything reasoning about it, so the reversal is a view choice and
    /// stays here.
    private var finishedSection: some View {
        section("Finished", count: controller.queue.finished.count) {
            ForEach(controller.queue.finished.reversed(), id: \.id) { record in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: outcomeSymbol(record.outcome))
                        .foregroundStyle(outcomeTint(record.outcome))
                        .frame(minWidth: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(controller.displayName(for: record.id))
                            .lineLimit(1)
                        if let detail = outcomeDetail(record.outcome) {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    /// Generic over the rows rather than taking `some View` as an opaque
    /// parameter: an opaque type in a closure's *return* position inside a
    /// result-builder parameter is the spelling that reads fine and does not
    /// resolve. Named `Rows` so the builder has something concrete to infer.
    private func section<Rows: View>(
        _ title: String,
        count: Int,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(count))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            rows()
        }
    }

    /// "58 plies" for a queued game, or nothing when its count was never
    /// captured. The count is the same number the estimate is denominated in,
    /// which is why it is shown: a reader who wonders why "about 9 min" jumped
    /// can see that the next game is four times the length of the last one.
    private func plyLabel(for id: PersistentIdentifier) -> String {
        guard let plies = controller.plyCount(for: id) else { return "" }
        return "\(plies) plies"
    }

    // MARK: Outcomes

    private func outcomeSymbol(_ outcome: AnalysisQueue<PersistentIdentifier>.Outcome) -> String {
        switch outcome {
        case .done:      "checkmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        case .failed:    "exclamationmark.triangle.fill"
        }
    }

    /// Green / secondary / red — and cancelled is deliberately *not* a warning
    /// colour. The user pressed Skip or Stop All; reporting their own choice
    /// back as a problem is the shape that teaches people to ignore warnings.
    private func outcomeTint(_ outcome: AnalysisQueue<PersistentIdentifier>.Outcome) -> Color {
        switch outcome {
        case .done:      .green
        case .cancelled: .secondary
        case .failed:    .red
        }
    }

    private func outcomeDetail(_ outcome: AnalysisQueue<PersistentIdentifier>.Outcome) -> String? {
        switch outcome {
        case .done:                    nil
        case .cancelled:               "Stopped. Evaluations recorded before the stop were kept."
        case .failed(let message):     message
        }
    }

    // MARK: Footer

    /// Pinned below the scroll rather than at the end of it: Stop All must be
    /// reachable without scrolling past a hundred queued rows to find it, which
    /// is the one thing a long list would otherwise cost.
    @ViewBuilder
    private var footer: some View {
        HStack {
            Spacer()
            if controller.queue.isActive {
                Button("Stop All", role: .destructive) {
                    controller.stopAll()
                }
                .accessibilityIdentifier(AccessibilityID.analysisQueueStopAll)
            } else {
                // Clearing the log also hides the Library's toolbar item (its
                // visibility rule reads `hasFailures`), which is what makes
                // this the acknowledgement rather than a mere tidy-up. The
                // window stays open — a window that closed itself when you
                // pressed a button inside it is the popover behaviour this
                // whole view exists to leave behind.
                Button("Clear") {
                    controller.clearFinished()
                }
                .accessibilityIdentifier(AccessibilityID.analysisQueueClear)
            }
        }
        .padding(16)
        .background(.bar)
    }
}

// MARK: Previews

/// **One preview, and only the empty state**, which is a waiver rather than an
/// oversight: `AnalysisQueue` is `private(set)` on the controller by design —
/// every mutation goes through a controller method — so a canvas cannot seed a
/// running batch without an engine subprocess and a model container. The states
/// worth looking at are exactly the ones a preview cannot reach.
///
/// What this one *does* witness is the branch a reader hits by accident: opening
/// the window from the Window menu with nothing running. That branch renders no
/// header clock, no search panel and no lists, which would be an easy thing to
/// leave as a blank rectangle — the layout it comes out with is the check.
///
/// The rest is the boardless checklist's, which names the states by hand.
#Preview("Idle") {
    AnalysisQueueStatusWindowView()
        .environment(AnalysisQueueController())
        .frame(width: 520, height: 560)
}
