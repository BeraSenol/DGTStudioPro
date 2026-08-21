import SwiftData
import SwiftUI

// MARK: Library Chrome

// The Library's self-contained furniture, split out of the destination: the filter menu, the
// filter chip bar, the empty states, and the two small labels. Everything here is a pure function
// of its parameters - no destination state.

/// The search-independent filter half; stays a menu (the discoverable entry point).
/// Toggles, not a picker: the state stopped being single-valued ("1-0 and 0-1" must be expressible).
struct LibraryFilterMenu: View {

    @Binding var searchTokens: [LibrarySearchToken]

    private var hasActiveFilters: Bool { !searchTokens.isEmpty }

    /// Membership as a `Binding<Bool>`; appends so chips sit in the order they were chosen.
    private func binding(for token: LibrarySearchToken) -> Binding<Bool> {
        Binding(
            get: { searchTokens.contains(token) },
            set: { isOn in
                if isOn {
                    if !searchTokens.contains(token) { searchTokens.append(token) }
                } else {
                    searchTokens.removeAll { $0 == token }
                }
            }
        )
    }

    var body: some View {
        Menu {
            ForEach(LibrarySearchToken.allCases) { token in
                Toggle(isOn: binding(for: token)) {
                    LibrarySearchTokenLabel(token: token)
                }
            }
            if hasActiveFilters {
                Divider()
                Button("Clear Filters") { searchTokens.removeAll() }
            }
        } label: {
            Label("Filter", systemImage: hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .menuIndicator(.hidden)
        .help(hasActiveFilters
              ? "Filters are narrowing the list"
              : "Filter by result or analysis state")
    }
}

/// One token rendering for chip and menu row, so the two cannot drift. State arrives as a literal -
/// a facet never consults the queue.
struct LibrarySearchTokenLabel: View {

    let token: LibrarySearchToken

    var body: some View {
        switch token {
        case .analyzed:   AnalysisLabel(state: .analyzed, title: token.displayName)
        case .unanalyzed: AnalysisLabel(state: .unanalyzed, title: token.displayName)
        case .result:     Label(token.displayName, systemImage: token.symbol)
        }
    }
}

/// Clearable filter chip. For a programmatic player filter it is the whole UI - the state's one face and exit.
struct LibraryFilterChipBar: View {

    let filter: LibraryFilter
    let onClear: (() -> Void)?

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                Text("\(filter.kindLabel): \(filter.displayName)")
                    .lineLimit(1)
                Button {
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Show the full Library")
                .accessibilityIdentifier(AccessibilityID.libraryFilterChipClear)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(.secondary.opacity(0.15)))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityID.libraryFilterChip)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Two vocabularies: an empty library invites importing; an empty filter result names the filter.
struct LibraryEmptyStateView: View {

    let filter: LibraryFilter?

    var body: some View {
        if let filter {
            ContentUnavailableView {
                Label("No \(filter.displayName) Games", systemImage: filter.systemImage)
            } description: {
                Text("No games match this \(filter.kindLabel.lowercased()) yet.")
            }
        } else {
            ContentUnavailableView {
                Label("No Games", systemImage: "books.vertical")
            } description: {
                Text("Import a PGN file to get started.")
            }
        }
    }
}

/// Gear + count while live; warning + counts after a failed drain, until Clear acknowledges - an error is
/// never swallowed by the batch ending. A clean drain hides it. Drawn through `AnalyzingGear` with `AnalysisLabel`.
struct LibraryQueueStatusLabel: View {

    let queue: AnalysisQueue<PersistentIdentifier>

    var body: some View {
        HStack(spacing: 6) {
            if queue.isActive {
                AnalyzingGear()
            } else {
                // Filled - a queue holding failures is a concluded bad outcome, and the app's
                // other three failure triangles are filled. See `DGTConnectionView` for the rule.
                Image(systemName: "exclamationmark.triangle.fill")
            }
            // `batchPosition`, not `completedCount` - the queue owns the arithmetic; both surfaces read it.
            Text("\(queue.batchPosition)/\(queue.totalCount)")
                .monospacedDigit()
        }
    }
}
