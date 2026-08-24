import os
import SwiftData
import SwiftUI

/// Routing wrapper, fifth in the `EvaluationGraphRequest` family: `openWindow(value:)` routes by
/// the value's *type*, and the main group already owns `PersistentIdentifier` - a bare id here
/// would make opening a game open a tag editor.
enum SmartTagEditorRequest: Hashable, Codable, Sendable {
    case new
    case edit(PersistentIdentifier)
}

/// The editor as its own window (16 Aug 2026, by request; it was a sheet over whichever tab
/// pressed +). The window owns the commit - the one Library write outside `PGNStore` - because
/// a window cannot hand a draft back to a presenter the way a sheet's closure did.
struct SmartTagEditorWindow: View {

    // MARK: Stored Properties

    let request: SmartTagEditorRequest?

    private static let logger = AppLog.logger(.smarttags)

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext

    // MARK: Body

    var body: some View {
        if let draft {
            SmartTagEditorView(draft: draft, onSave: commit)
        } else {
            // A stale edit request (tag deleted between the context menu and this render) or a
            // request-less restoration. One message for both: the remedy is identical.
            ContentUnavailableView(
                "No Tag to Edit",
                systemImage: "tag.slash",
                description: Text("The tag is gone. Close this window and create a new one from the sidebar.")
            )
            .frame(width: 420, height: 260)
        }
    }

    // MARK: Resolution

    /// `.new` is always constructible; `.edit` resolves through the context and refuses
    /// tombstones - the id→model cast + `isDeleted` pairing, seventh site.
    private var draft: TagDraft? {
        switch request {
        case .new:
            TagDraft()
        case .edit(let id):
            (modelContext.model(for: id) as? SmartTag).flatMap { tag in
                tag.isDeleted ? nil : TagDraft(editing: tag)
            }
        case nil:
            nil
        }
    }

    // MARK: Commit

    /// Insert-or-update from the editor's draft, one save either way - moved whole from
    /// `ContentView.commit` with the window (16 Aug 2026). A new tag appends to the sidebar:
    /// reorder rewrites the run 0..n, so max + 1 is always the tail.
    private func commit(_ draft: TagDraft) {
        if let tag = draft.editing {
            tag.name = draft.name
            tag.colorName = draft.colorName
            tag.matchAll = draft.matchAll
            tag.rules = draft.rules
        } else {
            var last = FetchDescriptor<SmartTag>(
                sortBy: [SortDescriptor(\.sortIndex, order: .reverse)]
            )
            last.fetchLimit = 1
            let tail = ((try? modelContext.fetch(last))?.first?.sortIndex ?? -1) + 1
            modelContext.insert(
                SmartTag(
                    name: draft.name,
                    colorName: draft.colorName,
                    matchAll: draft.matchAll,
                    rules: draft.rules,
                    sortIndex: tail
                )
            )
        }
        do {
            try modelContext.save()
        } catch {
            // The must-reach-somewhere trace tag writes owe (`ContentView.saveTags`'s rule).
            Self.logger?.error(
                "Tag commit failed to save: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

// MARK: Previews

#Preview("New Tag") {
    SmartTagEditorWindow(request: .new)
        .modelContainer(for: SmartTag.self, inMemory: true)
}

/// The stale-request arm - the branch a reader hits by deleting a tag under an open editor.
#Preview("No Tag") {
    SmartTagEditorWindow(request: nil)
        .modelContainer(for: SmartTag.self, inMemory: true)
}
