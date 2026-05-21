//
//  DGTStudioProApp.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 24/03/2026.
//

import SwiftData
import SwiftUI

@main
internal struct DGTStudioProApp: App {

    /// Shared `ModelContainer` for the whole app. Multiple tabs share
    /// one container so `PersistentIdentifier`s round-trip correctly.
    private let sharedContainer: ModelContainer = {
        do {
            return try ModelContainer(for: PGN.self)
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // One unified `WindowGroup` parameterised by an optional
        // `PersistentIdentifier`. Tabs with a nil value land on Library;
        // tabs with a value land on Board showing that game.
        //
        // With "Prefer Tabs: Always" in System Settings → Desktop &
        // Dock, additional windows of this group merge as native macOS
        // tabs of the existing window — Safari/Finder behavior. macOS
        // handles the tab bar, ⌘T, ⌘W, ⌘⇧[/], drag-rearrange, "Merge
        // All Windows," and window-state restoration.
        //
        // Library and Board can't tab together if they live in
        // separate `WindowGroup`s — macOS only tabs windows from the
        // same group. Hence one group, content varies by bound value.
        WindowGroup("DGT Studio Pro", for: PersistentIdentifier.self) { $gameID in
            ContentView(loadedGameID: $gameID)
        }
        .modelContainer(sharedContainer)

        Settings {
            SettingsView()
        }
    }
}
