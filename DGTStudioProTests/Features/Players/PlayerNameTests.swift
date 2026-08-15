import Testing
@testable import DGTStudioPro

/// The one display rule for player names. Nonisolated — `PlayerName`
/// is a pure enum over strings, so no container and no `@MainActor`. The
/// order and degenerate-input cases moved here verbatim from
/// `PGNDisplayTests` when the transform left `PGN`; the whitespace-fold and
/// idempotency cases are new.
@Suite("PlayerName — Display Order")
struct PlayerNameTests {
    
    /// Every input the suite exercises, in one place, so `displayIsIdempotent`
    /// can't drift from the cases that motivated it. Add a case above, get
    /// the idempotency check for free.
    static let inputs = [
        "Carlsen, Magnus", "Fischer, Robert", "Heylen, Christophe Maria",
        "Magnus Carlsen", "Nepo", "Carlsen,  Magnus ", "Carlsen,", ", Magnus",
        "   ", "", "?", "Carlsen, Magnus, Jr", "Magnus   Carlsen", "  Bera\n",
    ]
    
    // MARK: Order
    
    @Test func flipsLastCommaFirstIntoDisplayOrder() {
        #expect(PlayerName.displayForm(of: "Carlsen, Magnus") == "Magnus Carlsen")
        #expect(PlayerName.displayForm(of: "Fischer, Robert") == "Robert Fischer")
    }
    
    @Test func preservesMultiPartGivenNames() {
        #expect(PlayerName.displayForm(of: "Heylen, Christophe Maria")
                == "Christophe Maria Heylen")
    }
    
    @Test func passesThroughNamesAlreadyInDisplayOrder() {
        #expect(PlayerName.displayForm(of: "Magnus Carlsen") == "Magnus Carlsen")
        #expect(PlayerName.displayForm(of: "Nepo") == "Nepo")
    }
    
    // MARK: Degenerate Input
    
    @Test func handlesStrayCommasAndEmptyInput() {
        #expect(PlayerName.displayForm(of: "Carlsen,") == "Carlsen")  // no given name
        #expect(PlayerName.displayForm(of: ", Magnus") == "Magnus")   // no surname
        #expect(PlayerName.displayForm(of: "   ") == "")
        #expect(PlayerName.displayForm(of: "") == "")
    }
    
    /// `"?"` is a string like any other here. What a placeholder *means* is
    /// `resolvePlayer`'s call (no player) and `GameHeadline`'s (print the
    /// glyph) — never this transform's.
    @Test func passesThroughThePlaceholderTag() {
        #expect(PlayerName.displayForm(of: "?") == "?")
    }
    
    // MARK: Whitespace Fold
    
    @Test func collapsesWhitespaceRunsAndNewlines() {
        #expect(PlayerName.displayForm(of: "Magnus   Carlsen") == "Magnus Carlsen")
        #expect(PlayerName.displayForm(of: "Carlsen,\n Magnus") == "Magnus Carlsen")
        #expect(PlayerName.displayForm(of: "  Bera\n") == "Bera")
    }
    
    /// The display fold is *total*: after `displayForm`, `normalizedKey` has
    /// nothing left to collapse, so it degenerates to `lowercased()`.
    @Test(arguments: PlayerNameTests.inputs)
    func displayFormLeavesNothingForTheIdentityFold(_ raw: String) {
        let display = PlayerName.displayForm(of: raw)
        #expect(Player.normalizedKey(for: display) == display.lowercased())
    }
    
    /// Both arrival forms of one name reach one identity. The tag form must go
    /// through `displayForm` here because `resolvePlayer` display-forms *before*
    /// keying — keying a raw "Carlsen, Magnus" is not a path the app takes.
    @Test func bothArrivalFormsReachOneIdentity() {
        let fromDisplay = Player.normalizedKey(for: PlayerName.displayForm(of: "Magnus   Carlsen"))
        let fromTag     = Player.normalizedKey(for: PlayerName.displayForm(of: "Carlsen, Magnus"))
        #expect(fromDisplay == fromTag)
        #expect(fromDisplay == "magnus carlsen")
    }
    
    // MARK: Idempotency
    
    /// The old rotation bug: a second comma made the output non-comma-
    /// free, so pass two flipped it again ("Magnus, Jr Carlsen" →
    /// "Jr Carlsen Magnus").
    @Test func foldsANonstandardSecondComma() {
        #expect(PlayerName.displayForm(of: "Carlsen, Magnus, Jr") == "Magnus Jr Carlsen")
    }
    
    @Test(arguments: PlayerNameTests.inputs)
    func displayIsIdempotent(_ raw: String) {
        let once = PlayerName.displayForm(of: raw)
        #expect(PlayerName.displayForm(of: once) == once,
                "'\(raw)' rotated or re-folded on a second pass")
    }
}
