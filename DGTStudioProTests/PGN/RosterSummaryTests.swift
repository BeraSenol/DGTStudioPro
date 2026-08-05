import Foundation
import Testing
@testable import DGTStudioPro

/// The roster's display contract (D22′, as revised by D55′) — and the first
/// witness for the date/round formatting, which `PGN` has carried untested
/// since April and the live inspector carried twice.
///
/// **Four of these pins asserted the pre-D55′ contract until 4 Aug 2026**, and
/// they are the reason that decision has a number. M10 collapsed the four
/// display placeholders into one em dash, argued the collapse properly at the
/// declaration, and left this suite pinning `?`, `????.??.??` and `*`. The
/// tests were not wrong when written and they were not wrong to fail; what was
/// wrong is that a change to a *recorded display contract* shipped without
/// them, which is the "tests land in the same change as the behaviour they
/// cover" agreement. They now pin the shipped rule, plus the two claims the
/// collapse introduced and nothing checked: the recording split, and the
/// display/export separation that keeps the glyph out of the reference bytes.
///
/// Nonisolated: `RosterSummary` is a pure value; the `PGN` projection is a
/// passive read exercised by the inspectors. The *live* projection is pinned
/// here as of D44′ — and the suite's isolation is what does the pinning, so
/// this annotation is load-bearing rather than stylistic.
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
    
    /// A stored `"?"` **folds to the display glyph** and a real value passes
    /// through verbatim (D55′).
    ///
    /// This asserted the opposite until 4 Aug — "both doors already store `?`,
    /// so a second placeholder layer would be a lie about where the value came
    /// from". That reasoning was sound and lost on its own merits: the reader
    /// never sees where a value came from, only four different marks on one
    /// panel. The half that survives is the second line — a real Site is not a
    /// placeholder and must never be folded.
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

    /// **The recording split, which is the whole reason `isRecording` exists
    /// and had no witness at all.** The same token means two things: on the
    /// live projection `*` is *true* — the game is ongoing — while on a stored
    /// game it came from the import door (Decision #3 admits `*` there and
    /// refuses it at the archive door) and means "this file didn't say".
    ///
    /// Asserted through both constructors rather than by setting the flag,
    /// because the claim is that *the constructor* decides: only the live
    /// projection may say `*`.
    @Test func onlyTheLiveProjectionShowsTheOngoingToken() {
        let live = RosterSummary(
            LiveGame.Roster(event: "Club Night", site: "Home", white: "A", black: "B"),
            result: .ongoing
        )
        #expect(live[.result] == "*")
        #expect(summary(result: .ongoing)[.result] == RosterSummary.displayUnknown)
    }

    /// **Display folds; export does not.** D24′ pins the reference files byte
    /// for byte, where an unknown is `?`, a missing date is `????.??.??` and
    /// `*` is a real result token — so the em dash must never reach
    /// `tagValue(for:)`. `PGNSerializerTests` proves the bytes end to end; this
    /// pins the *separation*, which is the thing a future reader tidying two
    /// near-identical switches would collapse.
    @Test func exportVocabularyIsUntouchedByTheDisplayFold() {
        let roster = summary(event: "?", date: nil, round: nil, result: .ongoing)
        #expect(roster.tagValue(for: .event)  == RosterSummary.unknownTag)
        #expect(roster.tagValue(for: .date)   == RosterSummary.unknownDate)
        #expect(roster.tagValue(for: .round)  == RosterSummary.unknownTag)
        #expect(roster.tagValue(for: .result) == "*")
    }

    /// The pin D44′ was missing. Building a `LiveGame.Roster` in a
    /// nonisolated suite and projecting it only compiles while `Roster` and
    /// the live init both stay off the main actor — so the deleted
    /// `@MainActor` cannot come back without turning this red.
    ///
    /// It is a *compile* failure, not an assertion failure, which is the
    /// whole point: the attribute's stated reason (that `Roster` inherits
    /// `LiveGame`'s isolation by nesting) was wrong for a month because
    /// every other `Roster` caller in the tree was already `@MainActor` for
    /// `LiveGame`'s sake, and so had no way to contradict it.
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
