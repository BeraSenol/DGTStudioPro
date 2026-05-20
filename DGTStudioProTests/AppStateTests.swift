//
//  AppStateTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/05/2026.
//

import Testing
import SwiftData
@testable import DGTStudioPro
import Foundation

@Suite("AppState — Tab Management")
@MainActor
struct AppStateTests {
    
    // MARK: Helpers
    
    private static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
    
    /// Inserts a freshly built PGN into `container` so it gets a real
    /// `persistentModelID` (needed for the dedup path that keys on it).
    private static func makePGN(
        in container: ModelContainer,
        white: String = "A",
        black: String = "B",
        moves: [String] = ["e4", "e5"]
    ) -> PGN {
        let pgn = PGN(
            event: "Test",
            site: "Test",
            white: white,
            black: black,
            moves: moves,
            result: .ongoing
        )
        container.mainContext.insert(pgn)
        return pgn
    }
    
    // MARK: Initial State
    
    @Test func initialStateHasNoTabsAndDefaultDestination() {
        let appState = AppState()
        #expect(appState.tabs.isEmpty)
        #expect(appState.activeTabID == nil)
        #expect(appState.activeTab == nil)
        #expect(appState.canOpenMoreTabs)
        #expect(appState.sidebarSelection == .destination(.board))
    }
    
    // MARK: Open
    
    @Test func openingFirstTabActivatesItAndSwitchesToBoard() throws {
        let container = try Self.makeContainer()
        let pgn = Self.makePGN(in: container)
        
        let appState = AppState()
        appState.sidebarSelection = .destination(.library)
        
        let tab = appState.openTab(pgn: pgn)
        
        #expect(tab != nil)
        #expect(appState.tabs.count == 1)
        #expect(appState.activeTabID == tab?.id)
        #expect(appState.sidebarSelection == .destination(.board))
    }
    
    @Test func openingExistingPGNActivatesExistingTabWithoutDuplication() throws {
        let container = try Self.makeContainer()
        let pgn = Self.makePGN(in: container)
        
        let appState = AppState()
        let first  = appState.openTab(pgn: pgn)
        let second = appState.openTab(pgn: pgn)
        
        #expect(appState.tabs.count == 1)
        #expect(first?.id == second?.id)
    }
    
    @Test func openingDistinctPGNsCreatesDistinctTabsAndActivatesNewest() throws {
        let container = try Self.makeContainer()
        let pgn1 = Self.makePGN(in: container, white: "A")
        let pgn2 = Self.makePGN(in: container, white: "B")
        
        let appState = AppState()
        let t1 = appState.openTab(pgn: pgn1)
        let t2 = appState.openTab(pgn: pgn2)
        
        #expect(appState.tabs.count == 2)
        #expect(t1?.id != t2?.id)
        #expect(appState.activeTabID == t2?.id)
    }
    
    @Test func openingHonorsTabCap() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        
        for i in 0 ..< AppState.maxTabs {
            _ = appState.openTab(
                pgn: Self.makePGN(in: container, white: "P\(i)")
            )
        }
        
        let overflow = Self.makePGN(in: container, white: "P-overflow")
        let result = appState.openTab(pgn: overflow)
        
        #expect(result == nil)
        #expect(appState.tabs.count == AppState.maxTabs)
        #expect(!appState.canOpenMoreTabs)
        #expect(!appState.canOpen(overflow))
    }
    
    @Test func openingExistingPGNAtCapStillActivatesExistingTab() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        
        var firstPGN: PGN?
        for i in 0 ..< AppState.maxTabs {
            let pgn = Self.makePGN(in: container, white: "P\(i)")
            if i == 0 { firstPGN = pgn }
            _ = appState.openTab(pgn: pgn)
        }
        
        // At cap. Switch active to last so we can verify the re-open
        // moves activation back to the first.
        appState.activate(id: appState.tabs.last!.id)
        let result = appState.openTab(pgn: firstPGN!)
        
        #expect(result != nil)
        #expect(appState.tabs.count == AppState.maxTabs)
        #expect(appState.activeTabID == result?.id)
    }
    
    // MARK: Close
    
    @Test func closingNonActiveTabLeavesActivationAlone() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        
        _      = appState.openTab(pgn: Self.makePGN(in: container, white: "A"))
        let t2 = appState.openTab(pgn: Self.makePGN(in: container, white: "B"))!
        let t3 = appState.openTab(pgn: Self.makePGN(in: container, white: "C"))!
        
        // t3 is active. Close t2 (not active).
        appState.closeTab(id: t2.id)
        #expect(appState.tabs.count == 2)
        #expect(appState.activeTabID == t3.id)
    }
    
    @Test func closingActiveMiddleTabActivatesRightNeighbor() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        
        _      = appState.openTab(pgn: Self.makePGN(in: container, white: "A"))
        let t2 = appState.openTab(pgn: Self.makePGN(in: container, white: "B"))!
        let t3 = appState.openTab(pgn: Self.makePGN(in: container, white: "C"))!
        
        appState.activate(id: t2.id)
        appState.closeTab(id: t2.id)
        
        #expect(appState.tabs.count == 2)
        #expect(appState.activeTabID == t3.id)
    }
    
    @Test func closingActiveLastTabActivatesLeftNeighbor() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        
        _      = appState.openTab(pgn: Self.makePGN(in: container, white: "A"))
        let t2 = appState.openTab(pgn: Self.makePGN(in: container, white: "B"))!
        let t3 = appState.openTab(pgn: Self.makePGN(in: container, white: "C"))!
        
        appState.activate(id: t3.id)
        appState.closeTab(id: t3.id)
        
        #expect(appState.tabs.count == 2)
        #expect(appState.activeTabID == t2.id)
    }
    
    @Test func closingLastTabClearsActiveID() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        
        let tab = appState.openTab(pgn: Self.makePGN(in: container))!
        appState.closeTab(id: tab.id)
        
        #expect(appState.tabs.isEmpty)
        #expect(appState.activeTabID == nil)
        #expect(appState.activeTab == nil)
    }
    
    @Test func closingUnknownIDIsNoOp() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        let tab = appState.openTab(pgn: Self.makePGN(in: container))!
        
        appState.closeTab(id: UUID())
        #expect(appState.tabs.count == 1)
        #expect(appState.activeTabID == tab.id)
    }
    
    // MARK: Activate
    
    @Test func activateChangesActiveTab() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        let t1 = appState.openTab(pgn: Self.makePGN(in: container, white: "A"))!
        let t2 = appState.openTab(pgn: Self.makePGN(in: container, white: "B"))!
        
        appState.activate(id: t1.id)
        #expect(appState.activeTabID == t1.id)
        
        appState.activate(id: t2.id)
        #expect(appState.activeTabID == t2.id)
    }
    
    @Test func activateWithUnknownIDIsNoOp() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        let tab = appState.openTab(pgn: Self.makePGN(in: container))!
        
        appState.activate(id: UUID())
        #expect(appState.activeTabID == tab.id)
    }
    
    // MARK: Predicates
    
    @Test func isOpenReflectsTabPresence() throws {
        let container = try Self.makeContainer()
        let pgn = Self.makePGN(in: container)
        
        let appState = AppState()
        #expect(!appState.isOpen(pgn))
        
        _ = appState.openTab(pgn: pgn)
        #expect(appState.isOpen(pgn))
    }
    
    @Test func canOpenAllowsExistingPGNEvenAtCap() throws {
        let container = try Self.makeContainer()
        let appState = AppState()
        
        var firstPGN: PGN?
        for i in 0 ..< AppState.maxTabs {
            let pgn = Self.makePGN(in: container, white: "P\(i)")
            if i == 0 { firstPGN = pgn }
            _ = appState.openTab(pgn: pgn)
        }
        
        let stranger = Self.makePGN(in: container, white: "X")
        #expect(!appState.canOpen(stranger))
        #expect(appState.canOpen(firstPGN!))
    }
}
