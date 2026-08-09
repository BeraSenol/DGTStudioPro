import Foundation
import SwiftData

/// Per-tab ephemeral state that survives sidebar destination switches — the split view's
/// `switch` recreates destination views, so anything worth keeping across a Board↔Library
/// round trip lives here. Tabs do not share state.
@Observable
@MainActor
internal final class TabState {
    
    // MARK: Board Destination
    
    /// The resolved PGN cache — the round trip is paid once per game, not per destination switch.
    internal var boardPGN: PGN?
    
    /// Working `Game` from `boardPGN`; surviving the switch is the point — the user keeps their
    /// scrub position.
    internal var boardGame: Game?
    
    /// Last load error for the bound id — drives the load-error card.
    internal var boardLoadError: String?
    
    /// Per-tab board perspective; survives a round trip, doesn't leak across tabs.
    internal var boardPerspective: PieceColor = .white
    
    /// Board inspector open? Default true.
    internal var boardInspectorPresented: Bool = true
    
    /// A manually-requested new-game sheet (sidebar's New Game). Here rather than destination
    /// `@State` so an unanswered request survives a destination round trip and re-presents.
    internal var manualNewGameRequested: Bool = false
    
    // MARK: Library Destination
    
    /// Library inspector open? Default `true` (code is truth — this doc had rotted to false).
    /// Gallery force-opens it; that hook only ever opens, so the two never fight.
    internal var libraryInspectorPresented: Bool = true

    // MARK: Players Destination

    internal var playersInspectorPresented: Bool = true
}
