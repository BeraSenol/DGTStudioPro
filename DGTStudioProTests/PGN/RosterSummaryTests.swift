//
//  RosterSummaryTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 23/07/2026.
//

import Foundation
import Testing
@testable import DGTStudioPro

/// The roster's display contract (D22′) — and the first witness for the
/// date/round formatting, which `PGN` has carried untested since April and
/// the live inspector carried twice.
///
/// Nonisolated: `RosterSummary` is a pure value; the two model projections
/// are passive reads exercised by the inspectors.
@Suite("Roster Summary — Seven Tag Display")
struct RosterSummaryTests {
    
    private func summary(
        event: String = "Club Night",
        site: String = "Home",
        date: Date? = nil,
        round: Int? = nil,
        white: String = "Carlsen, Magnus",
        black: String = "Nepomniachtchi, Ian",
        result: GameResult = .ongoing
    ) -> RosterSummary {
        RosterSummary(
            event: event, site: site, date: date, round: round,
            white: white, black: black, result: result
        )
    }
    
    /// The claim the section rests on: seven tags, in the standard's order.
    /// A reordering or an eighth case fails here before it reaches a sidebar.
    @Test func theRosterIsSevenTagsInStandardOrder() {
        #expect(SevenTagRoster.allCases.map(\.rawValue)
                == ["Event", "Site", "Date", "Round", "White", "Black", "Result"])
    }
    
    /// Players render in display form, matching the headline and the Library
    /// inspector — the live inspector used to show the raw tag.
    @Test func playersRenderInDisplayForm() {
        let roster = summary()
        #expect(roster[.white] == "Magnus Carlsen")
        #expect(roster[.black] == "Ian Nepomniachtchi")
    }
    
    /// Event and Site pass through: both doors already store `"?"` when the
    /// tag is absent, so a second placeholder layer would be a lie about
    /// where the value came from.
    @Test func eventAndSitePassThroughUnchanged() {
        let roster = summary(event: "?", site: "Wijk aan Zee")
        #expect(roster[.event] == "?")
        #expect(roster[.site] == "Wijk aan Zee")
    }
    
    @Test func anAbsentRoundReadsAsThePGNPlaceholder() {
        #expect(summary(round: nil)[.round] == "?")
        #expect(summary(round: 101)[.round] == "101")
    }
    
    /// The date placeholder is PGN's own `????.??.??`, not an em-dash: the
    /// row is reporting a tag, not the absence of a game.
    @Test func anAbsentDateReadsAsThePGNPlaceholder() {
        #expect(summary(date: nil)[.date] == "????.??.??")
    }
    
    /// A real date formats rather than placeholds. Deliberately not asserted
    /// against a literal — `.dateTime` is locale-dependent, and pinning a
    /// string here would fail on a machine set to another region.
    @Test func aPresentDateIsFormatted() {
        let formatted = summary(date: Date(timeIntervalSince1970: 1_700_000_000))[.date]
        #expect(formatted != "????.??.??")
        #expect(!formatted.isEmpty)
    }
    
    @Test func resultRendersInPGNNotation() {
        #expect(summary(result: .whiteWins)[.result] == "1-0")
        #expect(summary(result: .ongoing)[.result] == "*")
    }
}
