import Foundation
import SwiftData

/// App-wide registry of open games with unsaved changes — the unified `WindowGroup` has no
/// central tab list. `isDirty` is always false today: every editor commits through the store on
/// OK, so the delete path's discard-confirmation branch is dormant until an editor defers writes.
@Observable
@MainActor
internal final class OpenGamesRegistry {
    
    /// Identifiers of open games with unsaved changes.
    private var dirtyGames: Set<PersistentIdentifier> = []
    
    internal func markDirty(_ id: PersistentIdentifier) {
        dirtyGames.insert(id)
    }
    
    internal func markClean(_ id: PersistentIdentifier) {
        dirtyGames.remove(id)
    }
    
    internal func isDirty(_ id: PersistentIdentifier) -> Bool {
        dirtyGames.contains(id)
    }
}
