import Foundation
import SwiftData

/// Per-tab ephemeral state that survives sidebar destination switches - the split view's
/// `switch` recreates destination views, so anything worth keeping across a Board↔Library
/// round trip lives here. Tabs do not share state.
@Observable
@MainActor
final class TabState {
    
    // MARK: Board Destination
    
    /// The resolved PGN cache - the round trip is paid once per game, not per destination switch.
    var boardPGN: PGN?
    
    /// Working `Game` from `boardPGN`; surviving the switch is the point - the user keeps their
    /// scrub position.
    var boardGame: Game?
    
    /// Last load error for the bound id - drives the load-error card.
    var boardLoadError: String?
    
    /// Per-tab board perspective; survives a round trip, doesn't leak across tabs.
    var boardPerspective: PieceColor = .white
    
    /// Board inspector open? Default true.
    var boardInspectorPresented: Bool = true
    
    // (`manualNewGameRequested` stood here until 18 Aug 2026. It carried the session panel's
    // New Game press from inside this tab's hierarchy out to `BoardDestination`, which owned the
    // `openWindow` the panel could not reach. `SessionWindow` is a scene and reaches it directly,
    // so the flag, its setter and its `onChange` consumer all left together - D84′. The auto-offer
    // path never used it and is unaffected.)

    // MARK: Library Destination
    
    /// Library inspector open? Default `true` (code is truth - this doc had rotted to false).
    /// Gallery force-opens it; that hook only ever opens, so the two never fight.
    var libraryInspectorPresented: Bool = true

    // MARK: Players Destination

    var playersInspectorPresented: Bool = true
}
