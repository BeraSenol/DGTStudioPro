import SwiftUI

// MARK: Focused Value

/// The frontmost tab's editor draft binding, published via `.focusedSceneValue` (the
/// `activeGame` pattern) — the command drives whichever tab is front.
private struct TagEditorDraftKey: FocusedValueKey {
    typealias Value = Binding<TagDraft?>
}

extension FocusedValues {
    var tagEditorDraft: Binding<TagDraft?>? {
        get { self[TagEditorDraftKey.self] }
        set { self[TagEditorDraftKey.self] = newValue }
    }
}

// MARK: Commands

/// File ▸ New Smart Tag… — the reliable door into the editor: the sidebar header's + is
/// pointer-only (macOS exposes no AXButton for a borderless button in a List section header;
/// proven 29 July). The finding is about AX, and outlives the suite that proved it.
struct SmartTagCommands: Commands {

    @FocusedValue(\.tagEditorDraft) private var draft: Binding<TagDraft?>?

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Smart Tag…") { draft?.wrappedValue = TagDraft() }
                .disabled(draft == nil)
        }
    }
}
