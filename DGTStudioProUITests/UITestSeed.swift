//
//  UITestSeed.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 16/07/2026.
//

//  Deterministic in-memory sample data for UI tests.
//
//  Activated only when the app is launched with the `-uiTestSeed`
//  argument (which `DGTStudioProUITests` passes). Under that flag the
//  app uses an in-memory `ModelContainer` seeded with the games below,
//  so UI tests never touch — or depend on — the user's real library.
//
//  The game *names* are the test's addressing handles: each seeded game
//  becomes a `gameCard.<name>` accessibility identifier. The UI-test
//  target is a separate module and can't import these constants, so it
//  hardcodes matching string literals. Keep the two in sync.
//

import Foundation
import SwiftData

internal enum UITestSeed {
    
    /// Launch argument that switches the app into seeded, in-memory mode.
    internal static let launchArgument = "-uiTestSeed"
    
    /// True when the current process was launched for UI testing.
    internal static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
    
    /// Stable game names. These are the strings the UI test looks up as
    /// `gameCard.<name>`. (Mirror them in the test target.)
    internal enum GameName {
        // Aliases into the shared `SeedGameName` (AccessibilityID.swift, F8)
        // so the UI test target reads the same source instead of the old
        // hand-mirrored copy. Seeding call sites below read unchanged.
        internal static let quickMate = SeedGameName.quickMate   // legal mate, openable
        internal static let ruyLopez  = SeedGameName.ruyLopez    // legal opening, openable
        internal static let drawnGame = SeedGameName.drawnGame   // timed → "Timed" tag
        internal static let blackWins = SeedGameName.blackWins
    }
    
    /// Inserts the sample games into the (in-memory) container. Uses a
    /// freshly created `ModelContext` rather than `mainContext` so this
    /// can run from the App's container factory without main-actor
    /// isolation friction.
    internal static func seed(into container: ModelContainer) {
        let context = ModelContext(container)
        for game in games() {
            context.insert(game)
        }
        do {
            try context.save()
        } catch {
            assertionFailure("UI test seed failed: \(error)")
        }
    }
    
    private static func games() -> [PGN] {
        [
            // Fool's-mate: a real, legal checkmate. Round 1 + ends in "#"
            // exercises both the "First Round" and "Checkmate" smart tags,
            // and its moves are legal so opening it builds a `Game`
            // successfully (board shows, not the error state).
            PGN(
                event: "Test Open",
                site: "Memory",
                round: 1,
                white: "White, Player",
                black: "Black, Player",
                moves: ["f3", "e5", "g4", "Qh4#"],
                name: GameName.quickMate,
                result: .blackWins,
                contentHash: "seed-quickmate"
            ),
            // Ruy Lopez opening — also fully legal, a second openable game.
            PGN(
                event: "Test Open",
                site: "Memory",
                round: 2,
                white: "Lopez, Ruy",
                black: "Defender, The",
                moves: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6"],
                name: GameName.ruyLopez,
                result: .ongoing,
                contentHash: "seed-ruylopez"
            ),
            // A timed game (timeControl set) → "Timed" smart tag is non-empty.
            PGN(
                event: "Test Closed",
                site: "Memory",
                round: 7,
                white: "Giri, Anish",
                black: "Caruana, Fabiano",
                name: GameName.drawnGame,
                result: .draw,
                timeControl: "40/7200",
                contentHash: "seed-drawn"
            ),
            PGN(
                event: "Test Closed",
                site: "Memory",
                round: 3,
                white: "Firouzja, Alireza",
                black: "Ding, Liren",
                name: GameName.blackWins,
                result: .blackWins,
                contentHash: "seed-blackwins"
            ),
        ]
    }
}
