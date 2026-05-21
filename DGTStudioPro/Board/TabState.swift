//
//  TabState.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/05/2026.
//

import Foundation
import SwiftData

/// Per-tab ephemeral state that survives sidebar destination switches
/// within a single tab.
///
/// `NavigationSplitView`'s `switch selection { … }` body recreates the
/// detail view every time the sidebar changes destination. State stored
/// directly on a destination as `@State` is destroyed and reinitialized
/// on the switch, so scrub position, board perspective, inspector
/// visibility, etc. would be lost on every Board→Library→Board round-trip.
///
/// Hoisting that state into a per-tab `@Observable` held by `ContentView`
/// (which DOES survive the destination switch) restores the Safari/Finder
/// behavior the user expects: the tab remembers what you were doing on
/// each destination.
///
/// One instance per `ContentView` — i.e. one per native macOS tab. Tabs
/// do not share state with each other; that separation is what makes
/// `TabState` "per tab" rather than "per app".
///
/// Per-destination inspector visibility lives here (rather than as one
/// shared boolean) because Library, Board, Players, and Rankings show
/// different inspector content; carrying one bool per destination matches
/// each destination's natural default (Board on, Library off, etc.) and
/// preserves the user's per-destination preference across switches.
@Observable
@MainActor
internal final class TabState {
    
    // MARK: Board Destination
    
    /// Concrete PGN looked up from the tab's bound `loadedGameID`.
    /// `BoardDestination.loadIfNeeded()` resolves the ID and caches the
    /// resolved PGN here so the round-trip cost is paid once per game,
    /// not once per destination switch.
    internal var boardPGN: PGN?
    
    /// Working-copy `Game` built from `boardPGN`. Holds the per-ply
    /// state walk and the current scrub position. Surviving the
    /// destination switch is the whole point — the user keeps their
    /// scrub position when they peek at Library and come back.
    internal var boardGame: Game?
    
    /// Last load error for the bound `loadedGameID`, or `nil`. Drives
    /// the Board destination's error state when the lookup fails or
    /// the PGN's move list won't parse.
    internal var boardLoadError: String?
    
    /// Per-tab board perspective. Flipping the board in tab A doesn't
    /// affect tab B (they have separate `TabState`s); within tab A,
    /// flipping survives a Board→Library→Board round-trip.
    internal var boardPerspective: PieceColor = .white
    
    /// Whether the Board destination's inspector is open. Default `true`
    /// matches the design intent (game inspector is the primary content
    /// affordance on the Board destination).
    internal var boardInspectorPresented: Bool = true
    
    // MARK: Library Destination
    
    /// Whether the Library destination's inspector is open. Default
    /// `false`; `LibraryDestination` auto-opens it for Gallery view via
    /// `onAppear`/`onChange(of: viewMode)`.
    internal var libraryInspectorPresented: Bool = false
    
    // MARK: Players / Rankings Destinations
    
    internal var playersInspectorPresented: Bool = false
    internal var rankingsInspectorPresented: Bool = false
}
