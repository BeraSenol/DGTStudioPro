//
//  UITestSeed.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 22/05/2026.
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

    /// Scratch `UserDefaults` suite for seeded launches. The App points
    /// `.defaultAppStorage` here when `isActive`, so every `@AppStorage`
    /// in the window reads *and writes* this suite instead of the real
    /// preferences: daily use can't leak a view mode into a test run
    /// (the 29 July baseline — five row tests red because Players
    /// launched in whatever mode the human last browsed in), and test
    /// clicks can't pollute the human's settings. Wiped here, once per
    /// process (`static let`), so every run starts from the declared
    /// `@AppStorage` property defaults; wiping per-window would reset
    /// mid-test writes when opening a game spawns a second window.
    ///
    /// Rejected first: pinning the keys through launch-argument defaults
    /// (`-playersViewMode list`). The argument domain outranks every
    /// other domain on *reads*, so a test clicking a view-mode segment
    /// updated the control but the re-read snapped content back to the
    /// pin — two previously-green card tests went red the same day.
    ///
    /// `@MainActor` because `UserDefaults` is not `Sendable`, which makes
    /// this the app target's one static that strict concurrency rejects —
    /// and, under language mode 6, its only hard error. Both readers are
    /// `.defaultAppStorage(…)` inside `App.body`, already main-actor, so
    /// the isolation costs nothing at the call sites.
    ///
    /// Rejected: the unsafe-`nonisolated` opt-out, which is one keyword and
    /// silences it just as well. It would also be the first such opt-out in
    /// the app target — a standing invariant the between-milestone sweep
    /// greps for, spent here to avoid typing seven characters of isolation.
    /// (Spelled around deliberately: writing the token verbatim would make
    /// this comment a permanent false positive in that grep, which is the
    /// `.DS_Store` lesson — a check whose output always contains noise is a
    /// check being read past.) The trap
    /// worth naming: do not "fix" this by making it a computed `var`. The
    /// wipe is the initializer, so a computed form would re-wipe on every
    /// read and reset mid-test writes the moment opening a game spawns a
    /// second window — which is the failure the `static let` above exists
    /// to prevent.
    @MainActor internal static let scratchDefaults: UserDefaults = {
        let name = "BeraSenol.DGTStudioPro.uitest"
        // Never nil: the documented nil cases are passing the bundle ID
        // or the global domain, and this constant is neither.
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()
    
    /// Stable game names. These are the strings the UI test looks up as
    /// `gameCard.<name>` — shared with the UI suite via `SeedGameName`.
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
        // The same defaults production seeds (one factory — M-prs.5), so
        // the sidebar-tag tests exercise exactly what ships.
        for tag in SmartTag.defaultTags() {
            context.insert(tag)
        }
        context.insert(orphanedPlayer())
        do {
            try context.save()
        } catch {
            assertionFailure("UI test seed failed: \(error)")
        }
    }
    
    /// A registry row in no game — the one kind of orphan that still occurs
    /// now that `PGNStore.delete(_ pgns:)` collects the ones a game deletion
    /// would strand.
    ///
    /// Seeded because the sweep's UI test can no longer mint its own subject.
    /// It used to delete the game two seeded players shared and watch the
    /// toolbar item enable; the cascade collects those at the source, so that
    /// flow now proves the *opposite* thing — which the test asserts, and which
    /// left the sweep's own alert with no witness. This is that witness.
    ///
    /// Constructed rather than resolved through `PGNStore.resolvePlayer`: this
    /// file already builds `PGN`s directly, and going through the door would
    /// need a store on a context this method doesn't own. The name is
    /// deliberately nobody — a seeded game gaining this seat later would
    /// silently un-orphan the row and disable the item the test is here to
    /// click.
    private static func orphanedPlayer() -> Player {
        Player(name: "Casper Ghost", tagName: "Ghost, Casper")
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
