import Foundation
import Testing
@testable import DGTStudioPro

/// The Site tag's format rule (16 Aug 2026): PGN's `"City, Region CCC"`, enforced at the app's
/// authoring doors and nowhere else. Nonisolated - `SiteTag` is a pure value question and
/// `LiveGame.Roster` is a nonisolated nested type (a global actor never isolates nested types), so this suite is also the
/// standing witness that both stay reachable off the main actor.
@Suite("Site Tag - City, Region CCC")
struct SiteTagTests {

    // MARK: Format

    @Test("Well-formed sites pass", arguments: [
        "Hasselt, Limburg BEL",
        "New York City, NY USA",
        "St. Petersburg, Leningrad Oblast RUS",
        // An internal comma in the region passes deliberately - the standard's own examples
        // carry compound place names; the country code anchors the tail.
        "Ostend, West Flanders, Coastal BEL",
    ])
    func wellFormedSitesPass(site: String) {
        #expect(SiteTag.isWellFormed(site))
    }

    @Test("Malformed sites fail", arguments: [
        "Home",                     // the old prompt's example - no comma, no code
        "Hasselt BEL",              // no comma
        "Hasselt, BEL",             // no region between comma and code
        "Hasselt,  BEL",            // whitespace region
        ", Limburg BEL",            // no city
        "Hasselt, Limburg bel",     // lowercase code
        "Hasselt, Limburg BE",      // two-letter code
        "Hasselt, Limburg BELG",    // four-letter code
        "Hasselt, Limburg BEL ",    // trailing space - the code must end the value
        "?",                        // unknown is the *caller's* exemption, not a shape
        "",
    ])
    func malformedSitesFail(site: String) {
        #expect(!SiteTag.isWellFormed(site))
    }

    /// The built-in default site must satisfy the gate it ships beside. A deliberate literal
    /// twin of `NewLiveGameSheet.defaultSite`'s fallback: the two must agree, and this is the
    /// only automated thing positioned to notice them drifting apart.
    @Test func theBuiltInDefaultSiteIsWellFormed() {
        #expect(SiteTag.isWellFormed("Hasselt, Limburg BEL"))
    }

    // MARK: The Roster's Exemption

    private func roster(site: String) -> LiveGame.Roster {
        LiveGame.Roster(event: "Club Night", site: site, white: "Senol, Bera", black: "?")
    }

    @Test("Unknown and blank sites are exempt, not violations", arguments: ["?", "", "   "])
    func unknownAndBlankAreExempt(site: String) {
        #expect(!roster(site: site).siteViolatesFormat)
    }

    @Test func aMalformedSiteViolates() {
        #expect(roster(site: "Home").siteViolatesFormat)
    }

    @Test func aWellFormedSiteDoesNotViolate() {
        #expect(!roster(site: "Hasselt, Limburg BEL").siteViolatesFormat)
    }
}
