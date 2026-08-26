import Testing
import Foundation
@testable import DGTStudioPro

/// Pins the `"?"` ↔ empty-field boundary (M18 Phase 2 - the trio moved to
/// `LiveGameRosterForm.swift` with the form in M16 and had never been pinned). All three
/// roster sheets stage these; what they write lands in every export's tag section, so the
/// round trip is a persistence-adjacent contract, not a convenience. Nonisolated - pure
/// string folds, load-bearing.
@Suite("Roster Normalization")
struct RosterNormalizationTests {

    /// Only the exact placeholder unwraps - a name that happens to contain a question mark
    /// is a name.
    @Test func formValueUnwrapsExactlyThePlaceholder() {
        #expect(formValue("?") == "")
        #expect(formValue("") == "")
        #expect(formValue("Alice?") == "Alice?")
        #expect(formValue("Alice") == "Alice")
    }

    /// Whitespace-only commits as unknown; a real value commits trimmed; a literal `"?"`
    /// survives as itself (trim leaves it non-empty).
    @Test func tagValueFoldsEmptinessToThePlaceholder() {
        #expect(tagValue("") == "?")
        #expect(tagValue("   ") == "?")
        #expect(tagValue("\n\t") == "?")
        #expect(tagValue(" Alice ") == "Alice")
        #expect(tagValue("?") == "?")
    }

    /// The doc's claim - "kept adjacent so the round trip is obviously symmetric" - as
    /// arithmetic: unknown survives a seed-and-commit cycle, and so does a real value.
    @Test func theRoundTripIsSymmetric() {
        #expect(tagValue(formValue("?")) == "?")
        #expect(tagValue(formValue("Casual Game")) == "Casual Game")
        #expect(formValue(tagValue("   ")) == "")
        #expect(formValue(tagValue(" Hasselt, Limburg BEL ")) == "Hasselt, Limburg BEL")
    }

    /// `normalized` commits exactly the four text seats - the date, the round and the board
    /// identity ride through untouched. The board field is the one the edit-details sheet's
    /// copy-and-mutate doc calls out as survivable only because nothing rebuilds the roster.
    @Test func normalizedTouchesExactlyTheFourTextFields() {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var roster = LiveGame.Roster(
            event: " Club Night ",
            site: "",
            white: "?",
            black: " Baelus, Lorenzo ",
            board: "DGT 5031"
        )
        roster.date = date
        roster.round = 3

        let committed = normalized(roster)

        #expect(committed.event == "Club Night")
        #expect(committed.site == "?")
        #expect(committed.white == "?")
        #expect(committed.black == "Baelus, Lorenzo")
        #expect(committed.date == date)
        #expect(committed.round == 3)
        #expect(committed.board == "DGT 5031")
    }
}
