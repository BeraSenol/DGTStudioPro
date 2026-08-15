import Foundation
import SwiftData

/// Per-tab ephemeral state that survives sidebar destination switches — the split view's
/// `switch` recreates destination views, so anything worth keeping across a Board↔Library
/// round trip lives here. Tabs do not share state.
@Observable
@MainActor
final class TabState {
    
    // MARK: Board Destination
    
    /// The resolved PGN cache — the round trip is paid once per game, not per destination switch.
    var boardPGN: PGN?
    
    /// Working `Game` from `boardPGN`; surviving the switch is the point — the user keeps their
    /// scrub position.
    var boardGame: Game?
    
    /// Last load error for the bound id — drives the load-error card.
    var boardLoadError: String?
    
    /// Per-tab board perspective; survives a round trip, doesn't leak across tabs.
    var boardPerspective: PieceColor = .white
    
    /// Board inspector open? Default true.
    var boardInspectorPresented: Bool = true
    
    /// A manually-requested new-game sheet (sidebar's New Game). Here rather than destination
    /// `@State` so an unanswered request survives a destination round trip and re-presents.
    var manualNewGameRequested: Bool = false
    
    // MARK: Library Destination
    
    /// Library inspector open? Default `true` (code is truth — this doc had rotted to false).
    /// Gallery force-opens it; that hook only ever opens, so the two never fight.
    var libraryInspectorPresented: Bool = true

    // MARK: Players Destination

    var playersInspectorPresented: Bool = true
}
