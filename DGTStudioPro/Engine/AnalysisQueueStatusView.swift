import SwiftData
import SwiftUI

/// Toolbar popover content for the analysis queue: the running game with
/// its per-ply progress and a skip control, the waiting line with
/// per-item removal, any failures from this batch, and Stop All /
/// Dismiss. Pure rendering over `AnalysisQueueController` — every
/// mutation routes through the controller so the queue's decisions stay
/// in one place.
///
/// No `#Preview`: the queue is `private(set)` on the controller by
/// design (mutation only through controller methods), so a preview can't
/// seed interesting states without a run task. The popover's witness is
/// the M-batch manual checklist.
internal struct AnalysisQueueStatusView: View {
    
    // MARK: Static Constants
    
    /// The popover lists at most this many waiting / failed rows and
    /// summarizes the rest — a hundred-game batch shouldn't build a
    /// hundred rows into a popover.
    private static let rowDisplayLimit = 8
    
    // MARK: Stored Properties
    
    internal let controller: AnalysisQueueController
    
    // MARK: Body
    
    internal var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headerTitle)
                .font(.headline)
            
            if let current = controller.queue.current {
                currentRow(id: current)
            }
            
            if !controller.queue.waiting.isEmpty {
                waitingList
            }
            
            if controller.queue.hasFailures {
                failureList
            }
            
            footer
        }
        .padding(14)
        .frame(width: 320)
        .accessibilityIdentifier(AccessibilityID.libraryQueuePopover)
    }
    
    // MARK: Sections
    
    private var headerTitle: String {
        let queue = controller.queue
        guard queue.isActive else { return "Analysis finished" }
        // "Analyzing 3 of 7" — the running game is completed + 1. Clamped
        // for the transient lap between one game finishing and the next
        // being promoted.
        let position = min(queue.completedCount + 1, queue.totalCount)
        return "Analyzing \(position) of \(queue.totalCount)"
    }
    
    private func currentRow(id: PersistentIdentifier) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(controller.currentGameName ?? controller.displayName(for: id))
                    .lineLimit(1)
                Spacer()
                Button {
                    controller.skipCurrent()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop this game and continue with the next")
            }
            ProgressView(value: controller.currentProgress)
        }
    }
    
    private var waitingList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Up Next")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(controller.queue.waiting.prefix(Self.rowDisplayLimit), id: \.self) { id in
                HStack(spacing: 8) {
                    Text(controller.displayName(for: id))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        controller.removeWaiting(id)
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove from the queue")
                }
            }
            overflowNote(
                beyond: controller.queue.waiting.count - Self.rowDisplayLimit
            )
        }
    }
    
    private var failureList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Failed")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(
                controller.queue.failures.prefix(Self.rowDisplayLimit),
                id: \.id
            ) { record in
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.displayName(for: record.id))
                        .lineLimit(1)
                    if case .failed(let message) = record.outcome {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            overflowNote(
                beyond: controller.queue.failures.count - Self.rowDisplayLimit
            )
        }
    }
    
    /// "…and N more" when a list is truncated; nothing when it isn't.
    @ViewBuilder
    private func overflowNote(beyond hiddenCount: Int) -> some View {
        if hiddenCount > 0 {
            Text("…and \(hiddenCount) more")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private var footer: some View {
        if controller.queue.isActive {
            Button("Stop All", role: .destructive) {
                controller.stopAll()
            }
            .accessibilityIdentifier(AccessibilityID.libraryQueueStopAll)
        } else {
            // Only reachable in the drained-with-failures shape — the
            // toolbar item hides itself after a clean drain (see
            // `LibraryDestination`'s visibility rule), so this footer's
            // idle case exists to acknowledge errors. Clearing the log
            // hides the item, which dismisses this popover with it.
            Button("Dismiss") {
                controller.clearFinished()
            }
        }
    }
}
