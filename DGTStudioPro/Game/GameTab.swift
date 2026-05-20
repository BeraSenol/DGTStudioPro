//
//  GameTab.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/05/2026.
//

import Foundation

/// A single open game in the document model.
///
/// Each tab pairs a persisted `PGN` with its derived working-model
/// `Game`. The `Game` is built once at construction (eager state walk
/// per Phase 8's locks) and the same instance is retained for the tab's
/// lifetime — opening a tab is "fix the working model in memory," not
/// "load and discard on every view appearance."
///
/// Named `GameTab` rather than `Tab` to avoid clashing with SwiftUI's
/// `Tab` type (introduced in iOS 18 / macOS 15) in any file that also
/// imports SwiftUI.
@Observable
@MainActor
internal final class GameTab: Identifiable {
    
    // MARK: Stored Properties
    
    internal let id: UUID = UUID()
    internal let pgn: PGN
    internal let game: Game
    
    // MARK: Initializer
    
    /// Builds a tab by constructing its `Game` from the supplied PGN.
    /// Propagates `Game.BuildError` if the PGN's move list won't parse —
    /// the caller (typically `AppState.openTab(pgn:)`) treats failure as
    /// "tab can't be opened" and returns nil to its own caller.
    internal init(pgn: PGN) throws {
        self.pgn = pgn
        self.game = try Game(pgn: pgn)
    }
    
    // MARK: Computed Properties
    
    /// Display name for the tab strip — falls back to player names when
    /// the PGN has no friendly name set.
    internal var displayName: String {
        if !pgn.name.isEmpty { return pgn.name }
        return "\(pgn.white) vs \(pgn.black)"
    }
}
