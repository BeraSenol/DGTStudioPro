import SwiftUI

// MARK: Result Model

/// Outcome of importing a single PGN file in a batch. Drives one row in
/// the import status sheet.
struct ImportResult: Identifiable {
    let id = UUID()
    let fileName: String
    let outcome: Outcome
    
    enum Outcome {
        case imported(name: String)
        case failed(PGNStore.Error)
        
        /// The three buckets every consumer partitions into. The summary's
        /// counts, the row icon, and the row tint each open-coded this match,
        /// and each had to independently remember that a duplicate is *not*
        /// a failure - it's the no-op the user asked for.
        enum Category {
            case imported, duplicate, failed
        }
        
        var category: Category {
            switch self {
            case .imported:           .imported
            case .failed(.duplicate): .duplicate
            case .failed:             .failed
            }
        }
    }
}

/// Live state of a running (or finished) import batch. The Library owns
/// one of these as `@State` and mutates it per file; the sheet renders it.
struct ImportProgress {
    var total: Int
    var results: [ImportResult] = []
    var isFinished: Bool = false
    
    var completed: Int { results.count }
    
    var importedCount: Int  { count(of: .imported) }
    var duplicateCount: Int { count(of: .duplicate) }
    var failedCount: Int    { count(of: .failed) }
    
    /// `count(where:)`, not `filter { … }.count` - the old form built three
    /// throwaway arrays to ask three questions about their sizes.
    private func count(of category: ImportResult.Outcome.Category) -> Int {
        results.count { $0.outcome.category == category }
    }
}

// MARK: Sheet

struct ImportStatusView: View {
    
    let progress: ImportProgress
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
            
            // `ScrollView` + `LazyVStack`, NOT `List` (17 Aug 2026): the List crashed this
            // file's live preview every time - SwiftUI's `OutlineListCoordinator` hitting a
            // `fatalError` in `ViewListTree.visitItem` while AppKit estimated row heights
            // during `viewDidMoveToWindow` (`rowAtPoint:` → `computeTotalRowsSpan` →
            // `itemAtRow:`), a framework ordering bug reached through a `List` whose height
            // is still being negotiated as it attaches. Reproducible with static data and a
            // fresh preview agent, so not the preview's accumulated state.
            //
            // The `List` was buying nothing here: this is a read-only report - no selection,
            // no menus, no reordering - so an `NSOutlineView` was pure liability. Separators
            // and insets restated by hand to keep `.listStyle(.inset)`'s look.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(progress.results.enumerated()), id: \.element.id) { index, result in
                        if index > 0 {
                            Divider()
                        }
                        ImportResultRow(result: result)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .frame(minHeight: 200)
            
            Divider()
            
            footer
        }
        .frame(width: 460, height: 420)
    }
    
    // MARK: Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.isFinished ? "Import Complete" : "Importing…")
                .font(.headline)
            
            ProgressView(
                value: Double(progress.completed),
                total: Double(max(progress.total, 1))
            )
            
            Text("\(progress.completed) of \(progress.total)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding()
    }
    
    // MARK: Footer
    
    private var footer: some View {
        HStack {
            if progress.isFinished {
                summaryText
            }
            Spacer()
            Button(progress.isFinished ? "Done" : "Cancel", action: onDismiss)
                .keyboardShortcut(.defaultAction)
                .disabled(!progress.isFinished)
        }
        .padding()
    }
    
    @ViewBuilder
    private var summaryText: some View {
        let parts: [String] = {
            var p: [String] = []
            if progress.importedCount > 0  { p.append("\(progress.importedCount) imported") }
            if progress.duplicateCount > 0 { p.append("\(progress.duplicateCount) duplicate") }
            if progress.failedCount > 0    { p.append("\(progress.failedCount) failed") }
            return p
        }()
        Text(parts.isEmpty ? "Nothing imported" : parts.joined(separator: ", "))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: Row

private struct ImportResultRow: View {
    
    let result: ImportResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.body)
                .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var icon: String {
        switch result.outcome.category {
        case .imported:  "checkmark.circle.fill"
        case .duplicate: "document.on.document"
        case .failed:    "exclamationmark.triangle.fill"
        }
    }
    
    private var tint: Color {
        switch result.outcome.category {
        case .imported:  .green
        case .duplicate: .orange
        case .failed:    .red
        }
    }
    private var title: String {
        switch result.outcome {
        case .imported(let name):               return name
        case .failed(.duplicate(_, let name)):  return name
        case .failed:                           return result.fileName
        }
    }
    
    private var detail: String {
        switch result.outcome {
        case .imported:
            return result.fileName
        case .failed(.duplicate):
            return "Already in your Library, skipped."
        case .failed(.missingRequiredTags(let tags)):
            return "Missing required tags: \(tags.sorted().joined(separator: ", "))."
        case .failed(.malformedPGN(let reason)):
            return reason
        case .failed(.fileReadFailed):
            return "Couldn't read the file."
        case .failed(.ongoingGame):
            return "Game is ongoing."
        }
    }
}

// MARK: Previews

/// Mid-batch: `isFinished` false, so the header shows the determinate
/// progress and the dismiss affordance reads as an interruption rather
/// than an acknowledgement.
#Preview("Running") {
    ImportStatusView(
        progress: ImportProgress(
            total: 12,
            results: [
                ImportResult(fileName: "1. Bera vs Reinaud.pgn", outcome: .imported(name: "Bera vs Reinaud")),
                ImportResult(fileName: "2. Bera vs Lorenzo.pgn", outcome: .imported(name: "Bera vs Lorenzo")),
                ImportResult(fileName: "3. Lorenzo vs Reinaud.pgn", outcome: .imported(name: "Lorenzo vs Reinaud"))
            ],
            isFinished: false
        ),
        onDismiss: {}
    )
}

#Preview("Finished, All Imported") {
    ImportStatusView(
        progress: ImportProgress(
            total: 3,
            results: [
                ImportResult(fileName: "1. Bera vs Reinaud.pgn", outcome: .imported(name: "Bera vs Reinaud")),
                ImportResult(fileName: "2. Bera vs Lorenzo.pgn", outcome: .imported(name: "Bera vs Lorenzo")),
                ImportResult(fileName: "3. Lorenzo vs Reinaud.pgn", outcome: .imported(name: "Lorenzo vs Reinaud"))
            ],
            isFinished: true
        ),
        onDismiss: {}
    )
}

/// The failure rows and the summary counts that partition them.
/// `.ongoingGame` is the no-ongoing-archives rule arriving as an import result - a `*` game
/// is refused at the door, not stored and hidden.
///
/// The `.duplicate` row is deliberately absent: its associated
/// `PersistentIdentifier` can't be built without an inserted model, so
/// previewing it would mean standing up a container for one row. It is
/// covered instead by `PGNStoreTests`' dedupe pins and the import manual
/// check.
#Preview("Finished, Mixed Failures") {
    ImportStatusView(
        progress: ImportProgress(
            total: 5,
            results: [
                ImportResult(fileName: "1. Bera vs Reinaud.pgn", outcome: .imported(name: "Bera vs Reinaud")),
                ImportResult(fileName: "truncated.pgn", outcome: .failed(.malformedPGN(reason: "unbalanced braces"))),
                ImportResult(fileName: "no-tags.pgn", outcome: .failed(.missingRequiredTags(["White", "Black", "Result"]))),
                ImportResult(fileName: "adjourned.pgn", outcome: .failed(.ongoingGame)),
                ImportResult(fileName: "locked.pgn", outcome: .failed(
                    .fileReadFailed(URL(fileURLWithPath: "/tmp/locked.pgn"), underlying: CocoaError(.fileReadNoPermission))
                ))
            ],
            isFinished: true
        ),
        onDismiss: {}
    )
}
