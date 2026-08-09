import Foundation
import Testing
@testable import DGTStudioPro

/// The roster's display contract (D22′ as revised by D55′). Four pins asserted the pre-D55′
/// contract until ⌘U caught them — correct pins on a repealed rule, in a file the pass had not
/// opened; the lesson: grep the suite for the old rule's *words*.
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
    
    /// A stored `"?"` folds to the glyph; a real value passes verbatim — a real Site is never folded.
    @Test func aStoredUnknownFoldsToTheDisplayGlyph() {
        let roster = summary(event: "?", site: "Wijk aan Zee")
        #expect(roster[.event] == RosterSummary.displayUnknown)
        #expect(roster[.site] == "Wijk aan Zee")
    }

    /// Whitespace counts as absent, which `shown(_:)` decides and nothing else
    /// covered: a tag stored as `"  "` is a tag that doesn't say.
    @Test func aBlankTagFoldsLikeAnExplicitUnknown() {
        #expect(summary(event: "   ")[.event] == RosterSummary.displayUnknown)
        #expect(summary(event: "")[.event] == RosterSummary.displayUnknown)
    }

    @Test func anAbsentRoundReadsAsTheDisplayGlyph() {
        #expect(summary(round: nil)[.round] == RosterSummary.displayUnknown)
        #expect(summary(round: 101)[.round] == "101")
    }

    /// The date placeholder is the one display glyph, not PGN's own
    /// `????.??.??` — that spelling is the *export* vocabulary and stays on
    /// `tagValue(for:)`, which the separation pin below guards.
    @Test func anAbsentDateReadsAsTheDisplayGlyph() {
        #expect(summary(date: nil)[.date] == RosterSummary.displayUnknown)
    }

    /// A real date formats rather than placeholds. Deliberately not asserted
    /// against a literal — `.dateTime` is locale-dependent, and pinning a
    /// string here would fail on a machine set to another region.
    @Test func aPresentDateIsFormatted() {
        let formatted = summary(date: Date(timeIntervalSince1970: 1_700_000_000))[.date]
        #expect(formatted != RosterSummary.displayUnknown)
        #expect(formatted != RosterSummary.unknownDate)
        #expect(!formatted.isEmpty)
    }

    /// Decided results render in PGN notation; `*` on an *archived* game is an
    /// unknown like any other and takes the glyph (D55′).
    @Test func resultRendersInPGNNotation() {
        #expect(summary(result: .whiteWins)[.result] == "1-0")
        #expect(summary(result: .draw)[.result] == "1/2-1/2")
        #expect(summary(result: .ongoing)[.result] == RosterSummary.displayUnknown)
    }

    /// The recording split: `*` is *true* on the live projection and an import-door unknown on a
    /// stored game — only the constructor decides.
    @Test func onlyTheLiveProjectionShowsTheOngoingToken() {
        let live = RosterSummary(
            LiveGame.Roster(event: "Club Night", site: "Home", white: "A", black: "B"),
            result: .ongoing
        )
        #expect(live[.result] == "*")
        #expect(summary(result: .ongoing)[.result] == RosterSummary.displayUnknown)
    }

    /// **Display folds; export does not** — the em dash must never reach `tagValue(for:)` (D24′).
    /// This pins the *separation* a future reader tidying two switches would collapse.
    @Test func exportVocabularyIsUntouchedByTheDisplayFold() {
        let roster = summary(event: "?", date: nil, round: nil, result: .ongoing)
        #expect(roster.tagValue(for: .event)  == RosterSummary.unknownTag)
        #expect(roster.tagValue(for: .date)   == RosterSummary.unknownDate)
        #expect(roster.tagValue(for: .round)  == RosterSummary.unknownTag)
        #expect(roster.tagValue(for: .result) == "*")
    }

    /// The D44′ pin: building a `Roster` in a nonisolated suite compiles only while the projection
    /// stays off the main actor — a *compile* failure, the correct severity for an isolation fact.
    @Test func theLiveProjectionIsReachableOffTheMainActor() {
        let roster = LiveGame.Roster(
            event: "Club Night",
            site:  "Home",
            round: 7,
            white: "Carlsen, Magnus",
            black: "Nepomniachtchi, Ian"
        )
        let projected = RosterSummary(roster, result: .whiteWins)
        #expect(projected[.event]  == "Club Night")
        #expect(projected[.round]  == "7")
        #expect(projected[.white]  == "Magnus Carlsen")
        #expect(projected[.result] == "1-0")
    }
}
