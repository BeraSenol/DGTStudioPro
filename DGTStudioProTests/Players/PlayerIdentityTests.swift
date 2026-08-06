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

    // MARK: The Seat Guard (D61′)

    /// **These are new on 6 August 2026 (M12.2), and their absence was the
    /// finding.** D61′ shipped the seat guard as `GetInfoWindow.seatsCollide`
    /// with no test of its own — the suite above pinned its *input* and nothing
    /// pinned the predicate. A rule living inside one of its consumers is hard
    /// to test and easy to forget to extend, which is exactly what happened:
    /// the two live sheets refused nothing for a day.
    ///
    /// The spelling that matters is the one below — different spellings of one
    /// player must collide. A raw `!=` passes every other test in this suite
    /// and fails this one.
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

    /// The `Roster` accessor forwards rather than restating (D39′'s one recipe,
    /// two spellings). Asserted *against the predicate* rather than against a
    /// literal `true`, so the two cannot drift into disagreement while both
    /// keep passing — the `EvaluationGraphReading` rule.
    ///
    /// Nonisolated on purpose, and load-bearing: `Roster` is nested in the
    /// `@MainActor` `LiveGame` and does **not** inherit that isolation (D44′).
    /// If someone annotates `Roster`, this stops compiling rather than going
    /// red — which is the correct severity for an isolation claim.
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
