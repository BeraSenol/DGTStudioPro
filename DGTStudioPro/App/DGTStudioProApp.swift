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
    ///
    /// Under the `-uiTestSeed` launch argument the container is in-memory
    /// and pre-seeded with `UITestSeed`'s sample games, so UI tests run
    /// against deterministic data and never touch the real library. A
    /// normal launch is unaffected (persistent store, no seeding).
    private let sharedContainer: ModelContainer = {
        do {
            let inMemory = UITestSeed.isActive
            let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            let container = try ModelContainer(for: PGN.self, configurations: config)
            if inMemory { UITestSeed.seed(into: container) }
            return container
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
    
    /// Shared registry of open games with unsaved changes. Same
    /// create-once-on-the-App, inject-into-every-tab pattern as
    /// `sharedContainer`. Used by the Library's delete path to decide
    /// whether closing a deleted game's tab needs a discard confirmation.
    @State private var openGames = OpenGamesRegistry()
    
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
        //
        // `.defaultLaunchBehavior(.presented)` forces an initial window
        // even when there is nothing to restore. A value-based
        // `WindowGroup` otherwise opens NO window on a clean launch (the
        // case in UI tests, where the in-memory store restores nothing) —
        // it normally relies on session restoration to reopen windows.
        WindowGroup("DGT Studio Pro", for: PersistentIdentifier.self) { $gameID in
            ContentView(loadedGameID: $gameID)
                .environment(openGames)
        }
        .modelContainer(sharedContainer)
        .defaultLaunchBehavior(.presented)
        
        Settings {
            SettingsView()
        }
    }
}
