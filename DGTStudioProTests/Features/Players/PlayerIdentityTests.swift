import Testing
@testable import DGTStudioPro

/// `Player.identity(forTag:)` — is there a player in this seat tag, and which (D61′).
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

    /// Comma order is not identity (D23′'s one-way transform): tag form and display form are one person.
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

    // MARK: The Seat Guard (D61′)

    /// New with M12.2 — their absence was the finding: D61′ shipped the guard with no test of the
    /// predicate itself. Different spellings of one player must collide; a raw `!=` passes every
    /// other test in this suite.
    @Test func differentSpellingsOfOnePlayerCollide() {
        #expect(Player.seatsNameOnePlayer("Lopez, Ruy", "Ruy Lopez"))
        #expect(Player.seatsNameOnePlayer("Senol, Bera", "senol,   BERA"))
    }

    @Test func twoDifferentPlayersDoNotCollide() {
        #expect(!Player.seatsNameOnePlayer("Carlsen, Magnus", "Nepomniachtchi, Ian"))
        #expect(!Player.seatsNameOnePlayer("Şenol, Bera", "Senol, Bera"))
    }

    /// Two absences are not one player (D9′) — the exemption without which the
    /// commonest imported shape, both seats `?`, would refuse every edit to
    /// either seat.
    @Test(arguments: [("?", "?"), ("", ""), ("?", ""), ("   ", "?")])
    func twoUnknownSeatsNeverCollide(_ pair: (String, String)) {
        #expect(!Player.seatsNameOnePlayer(pair.0, pair.1))
    }

    /// One known seat against an unknown one is a normal game, not a collision
    /// — the arm that would break if the nil guard were written as "unknown
    /// equals unknown".
    @Test func aKnownSeatAgainstAnUnknownOneDoesNotCollide() {
        #expect(!Player.seatsNameOnePlayer("Carlsen, Magnus", "?"))
        #expect(!Player.seatsNameOnePlayer("?", "Carlsen, Magnus"))
    }

    /// The `Roster` accessor forwards rather than restates — asserted against the predicate, not a
    /// literal. Nonisolated, load-bearing: `Roster` does not inherit `LiveGame`'s isolation (D44′).
    @Test func theRosterAccessorAgreesWithThePredicate() {
        let collides = LiveGame.Roster(white: "Lopez, Ruy", black: "Ruy Lopez")
        let distinct = LiveGame.Roster(white: "Carlsen, Magnus", black: "Nepo")
        let unknown  = LiveGame.Roster()

        #expect(collides.seatsNameOnePlayer
                == Player.seatsNameOnePlayer(collides.white, collides.black))
        #expect(distinct.seatsNameOnePlayer
                == Player.seatsNameOnePlayer(distinct.white, distinct.black))
        #expect(unknown.seatsNameOnePlayer
                == Player.seatsNameOnePlayer(unknown.white, unknown.black))

        // The values themselves, so the agreement above can't be vacuous by
        // both sides being wrong together — the M5 lesson about two guards
        // agreeing on a value neither could produce.
        #expect(collides.seatsNameOnePlayer)
        #expect(!distinct.seatsNameOnePlayer)
        #expect(!unknown.seatsNameOnePlayer)
    }

    // MARK: Agreement with the resolver

    /// The identity matches the key a `Player` row actually carries — asserted against the
    /// initializer, not a re-derivation.
    @Test func identityMatchesTheKeyAPlayerRowCarries() throws {
        let tag = "Senol, Bera"
        let row = Player(name: PlayerName.displayForm(of: tag))

        #expect(try #require(Player.identity(forTag: tag)) == row.normalizedName)
    }
}
