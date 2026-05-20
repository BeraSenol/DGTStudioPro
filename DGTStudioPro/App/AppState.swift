//
//  AppState.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/05/2026.
//

import Foundation
import SwiftData

/// Top-level observable state for the app: the open-tabs document model
/// and the sidebar selection.
///
/// The document model is a small `tabs: [GameTab]` array with a cap of
/// `maxTabs`. Each `GameTab` wraps a `PGN` and its derived `Game`. Tabs
/// persist across destination switches — the user can be browsing the
/// Library, click Open on a game, switch to the Board destination,
/// switch back to the Library, and the tab is still there with its
/// scrub position intact.
///
/// Sidebar selection lives here because it's part of the app-level
/// "where is the user looking" axis, and because opening a tab from the
/// Library inspector needs to flip the sidebar to `.board` — having the
/// selection on `AppState` makes that a single side-effect inside
/// `openTab(pgn:)` rather than a callback threaded through three views.
@Observable
@MainActor
internal final class AppState {
    
    // MARK: Constants
    
    /// Cap on concurrently open tabs. The intent is "a small handful of
    /// games at once," not "unlimited document model" — the cap exists
    /// so the tab strip UI never has to grow horizontal-scroll behavior
    /// to accommodate arbitrarily many entries, and so memory cost of
    /// the per-tab state walks stays bounded.
    internal static let maxTabs: Int = 5
    
    // MARK: Sidebar
    
    internal var sidebarSelection: SidebarSelection = .destination(.board)
    
    // MARK: Tabs
    
    /// Open tabs in user-facing order (left to right in the tab strip).
    internal private(set) var tabs: [GameTab] = []
    
    /// ID of the currently active tab, or `nil` if there are no tabs.
    internal private(set) var activeTabID: GameTab.ID?
    
    // MARK: Derived
    
    internal var activeTab: GameTab? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }
    
    internal var canOpenMoreTabs: Bool {
        tabs.count < Self.maxTabs
    }
    
    /// Whether `pgn` is currently open in some tab.
    internal func isOpen(_ pgn: PGN) -> Bool {
        tabs.contains { $0.pgn.persistentModelID == pgn.persistentModelID }
    }
    
    /// Whether `pgn` can be opened via `openTab(pgn:)`: either it's
    /// already open (which becomes an activate-existing operation) or
    /// there's room for a new tab.
    internal func canOpen(_ pgn: PGN) -> Bool {
        isOpen(pgn) || canOpenMoreTabs
    }
    
    // MARK: Tab Management
    
    /// Opens `pgn` in a new tab — or activates the existing tab if `pgn`
    /// is already open — and switches the sidebar destination to
    /// `.board`. Returns the now-active tab, or `nil` if the tab cap was
    /// hit (and `pgn` isn't already open) or if `Game` construction
    /// failed (corrupt PGN).
    @discardableResult
    internal func openTab(pgn: PGN) -> GameTab? {
        let tab: GameTab
        if let existing = tabs.first(where: {
            $0.pgn.persistentModelID == pgn.persistentModelID
        }) {
            tab = existing
        } else {
            guard canOpenMoreTabs else { return nil }
            guard let new = try? GameTab(pgn: pgn) else { return nil }
            tabs.append(new)
            tab = new
        }
        activeTabID = tab.id
        sidebarSelection = .destination(.board)
        return tab
    }
    
    /// Closes the tab with `id`. If it was the active tab, activates the
    /// neighbor to the right (or to the left if the closed tab was last).
    /// If no tabs remain, `activeTabID` goes nil.
    internal func closeTab(id: GameTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        let wasActive = activeTabID == id
        tabs.remove(at: index)
        
        guard wasActive else { return }
        
        if tabs.isEmpty {
            activeTabID = nil
        } else {
            let newIndex = min(index, tabs.count - 1)
            activeTabID = tabs[newIndex].id
        }
    }
    
    /// Activates the tab with `id`. No-op if no such tab exists.
    internal func activate(id: GameTab.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }
}
