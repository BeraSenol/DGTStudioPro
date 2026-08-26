import Testing
@testable import DGTStudioPro

/// Pins the wood vocabulary (M18 Phase 1). Nonisolated, and that is load-bearing: the enum is
/// a `Sendable` value type, and the two color switches stay untested by decision - they are
/// asset-catalog symbols, so a missing colorset is a build error already. What *can* silently
/// break is below: the raw values ride `StorageKeys.boardStyle`, and `displayName` leans on a
/// constraint the type's doc states but nothing enforced.
@Suite("Board Style")
struct BoardStyleTests {

    /// Pinned on literals: five call sites bind these through `@AppStorage`, so a rename is a
    /// silent reset of every install's stored choice - the checkmate vocabulary's rule.
    @Test func rawValuesArePersistedSpellings() {
        #expect(BoardStyle.leather.rawValue == "leather")
        #expect(BoardStyle.rosewood.rawValue == "rosewood")
        #expect(BoardStyle.walnut.rawValue == "walnut")
        #expect(BoardStyle.wenge.rawValue == "wenge")
    }

    /// `displayName` is `.capitalized` and works *only* while every case is one lowercase word -
    /// the declaration says so and points a two-word wood at a switch. This is that sentence as
    /// a failure: a camelCase or multi-word case lands here before it renders as "Blondemaple".
    @Test func everyCaseIsASingleLowercaseWord() {
        for style in BoardStyle.allCases {
            #expect(style.rawValue.allSatisfy { $0.isLowercase && $0.isLetter })
        }
    }

    /// Four woods, four distinct display names - `CaseIterable` is what Settings' picker walks.
    @Test func displayNamesAreDistinctAndCapitalized() {
        let names = BoardStyle.allCases.map(\.displayName)
        #expect(names == ["Leather", "Rosewood", "Walnut", "Wenge"])
    }
}
