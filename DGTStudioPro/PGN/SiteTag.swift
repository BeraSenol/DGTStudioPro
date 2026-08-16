/// The Site tag's shape question, and nothing else: is a value spelled the way the PGN standard
/// dictates - `"City, Region CCC"`, city and region comma-separated, ending in an uppercase
/// three-letter IOC country code (`"Hasselt, Limburg BEL"`, `"New York City, NY USA"`)?
///
/// Format only, deliberately: `"?"` is the standard's *unknown* vocabulary, not a site shape, so
/// the unknown exemption lives with the caller (`LiveGame.Roster.siteViolatesFormat`) - this type
/// answering true for `"?"` would fold two questions into one answer. Enforced at the app's own
/// authoring doors only (16 Aug 2026, by request); the import door stays permissive - the same
/// asymmetry that admits `*` and self-play, because a file may say things the app would never author.
enum SiteTag {

    /// `"City, Region CCC"` - the first `", "` splits city from the rest, the last space splits
    /// region from the country code. A compound region (`"New York City, NY, Region USA"`) passes:
    /// the standard's own examples carry internal commas, and the code anchors the tail.
    static func isWellFormed(_ site: String) -> Bool {
        guard let comma = site.firstRange(of: ", ") else { return false }
        let city = site[site.startIndex..<comma.lowerBound]
        let rest = site[comma.upperBound...]

        guard let lastSpace = rest.lastIndex(of: " ") else { return false }
        let region  = rest[rest.startIndex..<lastSpace]
        let country = rest[rest.index(after: lastSpace)...]

        return city.contains(where: { !$0.isWhitespace })
            && region.contains(where: { !$0.isWhitespace })
            && country.count == 3
            && country.allSatisfy { $0.isLetter && $0.isUppercase }
    }
}
