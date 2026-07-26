//
//  OpenGamesRegistry.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 22/05/2026.
//

import Foundation
import SwiftData

/// App-wide registry of which open games have unsaved changes.
///
/// The unified `WindowGroup` has no central tab list, so when a PGN is
/// deleted from the Library we need a way to (a) decide whether the tab
/// showing it has unsaved edits and (b) close that tab. Closing is done
/// natively via `dismissWindow(value:)`; this registry answers (a).
///
/// One instance, created on `DGTStudioProApp` and injected into every
/// tab via `.environment(_:)` — same lifetime/sharing pattern as the
/// shared `ModelContainer`. (`@Environment(_:)` injection of the
/// convenience kind would create per-tab copies, which would defeat the
/// "shared across tabs" requirement.)
///
/// Nothing calls `markDirty` yet: the edit surfaces that exist (metadata via
/// `applyEdit`, movetext via `applyMovetextEdit`) commit through the store on
/// OK, so a tab is never left holding uncommitted state. `isDirty` is
/// therefore always `false` and the delete path always takes the
/// immediate-close branch. An editor that defers its write — inline
/// annotations, a live movetext buffer — calls `markDirty`/`markClean` and the
/// discard-confirmation branch goes live with no further wiring.
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
