import SwiftData
import SwiftUI

/// The analysis queue in full: the live search, both clocks, everything in line, everything
/// done with its outcome - the room the popover never had.
struct AnalysisQueueStatusWindowView: View {

    // MARK: Static Constants

    /// The scene id, once: `openWindow(id:)` takes a bare `String`, and a typo fails at *runtime*
    /// with a console warning and no window.
    static let sceneID = "analysis.queue"

    // MARK: Stored Properties

    @Environment(AnalysisQueueController.self) private var controller

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let search = controller.currentSearch {
                    searchPanel(search)
                } else if controller.queue.current != nil {
                    // Between plies and before the first `info` line - naming the state holds the layout still.
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

    /// Title, counted position, two clocks. `TimelineView`, not a published tick - a per-second
    /// write to an `@Observable` would invalidate every observer.
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
        // `batchPosition` is the one spelling of the numerator, shared with the toolbar's "3/18".
        return "Analyzing \(queue.batchPosition) of \(queue.totalCount)"
    }

    /// Only the knowable half: the projection drops off once the queue drains - "about 0 sec" is
    /// not the same statement as no estimate.
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

    /// The move in chess notation, not a ply ordinal - a bare ordinal reads as a full-move number
    /// and points at the wrong move for every black ply.
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
                // The *target*, not the live iteration: `progress.depth` climbs 1→18 inside every ply, so the
                // readout spun and read as the setting bouncing.
                searchFact("Depth", "\(search.targetDepth)")
                // Through `EvaluationBarReading` - this window, the graph and the bar cannot disagree about
                // what "+1.3" or "#4" looks like (the pinned grammar).
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

    /// "8.9 Mn/s" - the unit every engine front end shows; degrades to thousands below a million.
    private func speedLabel(_ nodesPerSecond: Int?) -> String {
        guard let nodesPerSecond else { return RosterSummary.displayUnknown }
        if nodesPerSecond >= 1_000_000 {
            return String(format: "%.1f Mn/s", Double(nodesPerSecond) / 1_000_000)
        }
        return "\(nodesPerSecond / 1_000) kn/s"
    }

    // MARK: Lists

    /// Everything in line, in run order, per-row removal. No cap - "…and 92 more" was a popover's
    /// apology for being a popover.
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

    /// Done, newest first - unlike the queue's completion-order storage: a log read during a live
    /// batch wants the newest where the eyes already are.
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

    /// Generic over the rows: an opaque return inside a result-builder parameter reads fine and
    /// does not resolve. Named `Rows` so the builder has something to infer.
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

    /// "58 plies to search" - searchable, not total: the number the estimate is
    /// denominated in, so a jumped "about 9 min" is explicable.
    private func plyLabel(for id: PersistentIdentifier) -> String {
        guard let plies = controller.plyCount(for: id) else { return "" }
        return "\(plies) plies to search"
    }

    // MARK: Outcomes

    private func outcomeSymbol(_ outcome: AnalysisQueue<PersistentIdentifier>.Outcome) -> String {
        switch outcome {
        case .done:      "checkmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        case .failed:    "exclamationmark.triangle.fill"
        }
    }

    /// Cancelled is deliberately not a warning colour - reporting the user's own choice back as a
    /// problem teaches people to ignore warnings.
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

    /// Pinned below the scroll: Stop All must be reachable without scrolling past a hundred rows.
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
                // Clearing also hides the Library's toolbar item (`hasFailures`). The window stays open - a
                // window that closes itself on a button press is the popover behaviour this view leaves behind.
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

/// One preview, empty state only - a waiver: the queue is `private(set)` by design, so a canvas
/// cannot seed a running batch without an engine and a container.
#Preview("Idle") {
    AnalysisQueueStatusWindowView()
        .environment(AnalysisQueueController())
        .frame(width: 520, height: 560)
}
