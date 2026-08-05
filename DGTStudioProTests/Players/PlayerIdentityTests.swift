//
//  PlayerIdentityTests.swift
//  DGTStudioProTests
//
//  Created by Supreme Leader on 05/08/2026.
//

import Testing
@testable import DGTStudioPro

/// `Player.identity(forTag:)` — "is there a player in this seat tag, and if so
/// which one" (D61′).
///
/// **Nonisolated**, because this is string arithmetic on a static and nothing
/// here touches a `ModelContext`. That matters more than usual: the function
/// was extracted so a *view* could ask the question without creating a row, so
/// a suite that needed a container would be evidence the extraction had failed.
///
/// This is the resolver's own rule, now stated once. The tests below are
/// therefore doing double duty — they pin the seat guard's input *and*
/// `PGNStore.resolvePlayer`'s placeholder handling, which had these three lines
/// inline until this pass.
@Suite("Player identity from a seat tag")
struct PlayerIdentityTests {

    // MARK: The absence of a player

    /// `?` and empty are the absence of a player, never a player named `?`
    /// (D9′). Whitespace-only counts as empty, and a bare comma folds to
    /// nothing through the display transform.
    @Test(arguments: ["?", "", "   ", ",", " , "])
    func placeholdersHaveNoIdentity(_ tag: String) {
        #expect(Player.identity(forTag: tag) == nil, "'\(tag)' produced an identity")
    }

    // MARK: One player, many spellings

    /// D23′'s one-way transform means comma order is not identity: the tag form
    /// and the display form are the same person.
    ///
    /// This is the case the seat guard exists for — a raw string comparison
    /// would let White be "Lopez, Ruy" and Black be "Ruy Lopez" and call them
    /// two people.
    @Test func commaOrderDoesNotChangeIdentity() {
        #expect(Player.identity(forTag: "Lopez, Ruy") == Player.identity(forTag: "Ruy Lopez"))
    }

    /// Casing and whitespace runs fold; diacritics deliberately do not (D9′ —
    /// "Bücher" is not "Bucher").
    @Test func casingAndWhitespaceFoldButDiacriticsDoNot() {
        #expect(Player.identity(forTag: "Senol, Bera") == Player.identity(forTag: "senol,   BERA"))
        #expect(Player.identity(forTag: "Şenol, Bera") != Player.identity(forTag: "Senol, Bera"))
    }

    /// Two genuinely different players stay different — the assertion that
    /// makes the ones above mean something.
    @Test func differentPlayersHaveDifferentIdentities() {
        #expect(Player.identity(forTag: "Carlsen, Magnus") != Player.identity(forTag: "Nepo"))
    }

    // MARK: Agreement with the resolver

    /// The identity this produces is the key a `Player` actually carries.
    ///
    /// Asserted against `Player`'s own initializer rather than against a
    /// literal: a hand-written `"bera senol"` would keep passing if the fold
    /// changed, which is exactly the divergence the extraction was meant to
    /// make impossible. `Player(name:)` is constructed, never inserted — no
    /// container, no store.
    @Test func identityMatchesTheKeyAPlayerRowCarries() throws {
        let tag = "Senol, Bera"
        let row = Player(name: PlayerName.displayForm(of: tag))

        #expect(try #require(Player.identity(forTag: tag)) == row.normalizedName)
    }
}
