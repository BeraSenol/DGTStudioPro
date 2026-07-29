//
//  SmartTagCommands.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 29/07/2026.
//

import SwiftUI

// MARK: Focused Value

/// Carries the frontmost tab's smart-tag editor draft binding up to the
/// scene's command menu — the `activeGame` pattern, second use. Published
/// by ``ContentView`` via `.focusedSceneValue`, so File ▸ New Smart Tag…
/// always opens the editor in whichever tab is in front, and is disabled
/// when no tab is (Settings frontmost, no windows).
private struct TagEditorDraftKey: FocusedValueKey {
    typealias Value = Binding<TagDraft?>
}

extension FocusedValues {
    internal var tagEditorDraft: Binding<TagDraft?>? {
        get { self[TagEditorDraftKey.self] }
        set { self[TagEditorDraftKey.self] = newValue }
    }
}

// MARK: Commands

/// File ▸ New Smart Tag… — the reliable door into the D12′ editor.
///
/// This exists because the sidebar header's + button is a pointer-only
/// affordance: macOS exposes no AXButton for a borderless button inside a
/// List section header, and a `.contextMenu` on that header never
/// surfaces — both proven by 29 July UITest runs (`.any` finds only an
/// inert StaticText mirror; `.buttons` finds nothing; the header
/// right-click produced no menu). A menu-bar command is reachable by
/// everything — pointer, keyboard, VoiceOver, and the UITest suite, which
/// already drives the Game and Diagnostics menus by title.
///
/// Ellipsis per HIG: the item opens the editor sheet rather than acting
/// immediately (`Export Session Log…` is the in-app precedent). Filed
/// under File after the New group, where Music keeps New Playlist — the
/// editor's design reference (D12′).
internal struct SmartTagCommands: Commands {

    @FocusedValue(\.tagEditorDraft) private var draft: Binding<TagDraft?>?

    internal var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Smart Tag…") { draft?.wrappedValue = TagDraft() }
                .disabled(draft == nil)
        }
    }
}
