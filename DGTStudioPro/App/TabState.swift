import Foundation
import SwiftData

/// Per-tab ephemeral state that survives sidebar destination switches: the split view's `switch`
/// recreates destination views, so anything worth keeping across a Board↔Library round trip lives
/// here. Tabs never share it.
@Observable
@MainActor
final class TabState {
    
    // MARK: Board Destination
    
    /// Resolved `PGN` cache, so the store round trip is paid once per game rather than once per
    /// destination switch.
    var boardPGN: PGN?
    
    /// Working `Game` from `boardPGN` - what keeps the reader's scrub position across a switch.
    var boardGame: Game?
    
    /// Last load error for the bound id; presented as an `.alert` on `BoardDestination`.
    var boardLoadError: String?
    
    var boardPerspective: PieceColor = .white
    var boardInspectorPresented: Bool = true
    
    // MARK: Library Destination
    
    /// Gallery force-opens this; that hook only ever opens, so the two never fight.
    var libraryInspectorPresented: Bool = true
    
    // MARK: Players Destination
    
    var playersInspectorPresented: Bool = true
}
