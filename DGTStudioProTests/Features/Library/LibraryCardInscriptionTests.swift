import Foundation
import Testing
@testable import DGTStudioPro

/// The card sheet's vocabulary and its pure derivation. Nonisolated, and that is load-bearing:
/// the type is a `Sendable` value enum with no view in reach, which is the arrangement that
/// keeps the mapping pinnable at all.
@Suite("Library Card Inscription")
struct LibraryCardInscriptionTests {

    /// A fixed, unambiguous locale for the date arm - the derivation takes it as a parameter
    /// precisely so this suite is not hostage to the machine's region settings.
    private static let posix = Locale(identifier: "en_US_POSIX")

    private static func date(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: Raw values

    /// Pinned on literals: the raw values ride `StorageKeys.libraryCardInscription`, so a rename
    /// is a silent reset of every install's choice - the checkmate vocabulary's rule.
    @Test func rawValuesArePersistedSpellings() {
        #expect(LibraryCardInscription.index.rawValue == "index")
        #expect(LibraryCardInscription.result.rawValue == "result")
        #expect(LibraryCardInscription.date.rawValue == "date")
        #expect(LibraryCardInscription.round.rawValue == "round")
    }

    /// A stored spelling this build no longer understands must fall back rather than trap -
    /// exercised through the options object's own read in `CollectionViewOptionsTests`; here the
    /// initializer's nil is the pinned half.
    @Test func anUnknownRawValueDoesNotDecode() {
        #expect(LibraryCardInscription(rawValue: "opening") == nil)
    }

    // MARK: Content - one distinct expectation per case (the D81' crossed-wiring lesson:
    // identical inputs cannot catch a mapping reading its neighbour's field).

    @Test func indexWritesTheOrdinal() {
        let content = LibraryCardInscription.index.content(
            index: 101, result: .whiteWins, date: Self.date(year: 2026, month: 8, day: 23), round: 7
        )
        #expect(content == .single("101"))
    }

    @Test func resultWritesTheCompactForm() {
        let content = LibraryCardInscription.result.content(
            index: 101, result: .draw, date: nil, round: 7
        )
        #expect(content == .single("½-½"))
    }

    /// The figure form is this surface's spelling alone - the stored raw value stays "1/2-1/2"
    /// everywhere else, so the two must differ here or the compact form quietly became the raw.
    @Test func theCompactDrawIsNotTheStoredSpelling() {
        #expect(LibraryCardInscription.compactResult(.draw) != GameResult.draw.rawValue)
        #expect(LibraryCardInscription.compactResult(.whiteWins) == GameResult.whiteWins.rawValue)
        #expect(LibraryCardInscription.compactResult(.blackWins) == GameResult.blackWins.rawValue)
        #expect(LibraryCardInscription.compactResult(.ongoing) == GameResult.ongoing.rawValue)
    }

    @Test func dateStacksMonthOverDay() {
        let content = LibraryCardInscription.date.content(
            index: 101,
            result: .whiteWins,
            date: Self.date(year: 2026, month: 8, day: 23),
            round: 7,
            locale: Self.posix
        )
        #expect(content == .stacked(top: "AUG", bottom: "23"))
    }

    @Test func roundWritesTheRound() {
        let content = LibraryCardInscription.round.content(
            index: 101, result: .whiteWins, date: nil, round: 7
        )
        #expect(content == .single("7"))
    }

    // MARK: Absent values - every arm falls back to the shared placeholder, never to empty.

    @Test func absentValuesWriteThePlaceholder() {
        #expect(
            LibraryCardInscription.index.content(index: nil, result: .draw, date: nil, round: nil)
                == .single(RosterSummary.displayUnknown)
        )
        #expect(
            LibraryCardInscription.date.content(index: 1, result: .draw, date: nil, round: 1)
                == .single(RosterSummary.displayUnknown)
        )
        #expect(
            LibraryCardInscription.round.content(index: 1, result: .draw, date: nil, round: nil)
                == .single(RosterSummary.displayUnknown)
        )
    }
}
