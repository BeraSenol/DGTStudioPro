import SwiftUI

// MARK: Focused Value

/// The frontmost tab's new-tag trigger, published via `.focusedSceneValue` (the
/// `boardGetInfoRequest` shape since the editor became a window, 16 Aug 2026 - a `Commands`
/// scene has no `openWindow`, so the tab opens it). Carried a `Binding<TagDraft?>` while the
/// editor was that tab's sheet.
private struct NewSmartTagRequestedKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var newSmartTagRequested: Binding<Bool>? {
        get { self[NewSmartTagRequestedKey.self] }
        set { self[NewSmartTagRequestedKey.self] = newValue }
    }
}

// MARK: Commands

/// File ▸ New Smart Tag… - the reliable door into the editor: the sidebar header's + is
/// pointer-only (macOS exposes no AXButton for a borderless button in a List section header;
/// proven 29 July). The finding is about AX, and outlives the suite that proved it.
struct SmartTagCommands: Commands {

    @FocusedValue(\.newSmartTagRequested) private var newTagRequested: Binding<Bool>?

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Smart Tag…") { newTagRequested?.wrappedValue = true }
                .disabled(newTagRequested == nil)
        }
    }
}
