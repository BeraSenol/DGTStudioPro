import Foundation
import SwiftData

/// A player identity materialized from seat tags (D9′). **Machine-managed**: created only by
/// `PGNStore.resolvePlayer(named:)`. Identity = display form lowercased, whitespace collapsed;
/// diacritics preserved ("Bücher" ≠ "Bucher"); first-seen casing wins. Orphans are collected by
/// every door that can strand one (D60′).
@Model
internal final class Player: Identifiable {
    
    // MARK: Stored Properties
    
    /// First-seen display form, from whichever raw tag created the row.
    internal var name: String

    /// The identity key; written only alongside `name` in `init`.
    internal var normalizedName: String

    /// First-seen **tag form** (D29′ — D23′'s "no inverse, remember instead"). The seat pickers
    /// insert this, never `name`; deriving tag form from display form is the forbidden inverse.
    internal var tagName: String?

    // MARK: Relationships
    
    /// Inverses of `PGN.whitePlayer`/`blackPlayer`; `.nullify` so a deletion strands no games.
    @Relationship(deleteRule: .nullify, inverse: \PGN.whitePlayer)
    internal var whiteGames: [PGN] = []
    
    @Relationship(deleteRule: .nullify, inverse: \PGN.blackPlayer)
    internal var blackGames: [PGN] = []
    
    // MARK: Computed Properties
    
    internal var id: PersistentIdentifier { persistentModelID }
    
    // MARK: Initializers
    
    /// `name` must already be display form; the resolver is the only production caller and always
    /// supplies `tagName` — the default exists for fixtures.
    internal init(name: String, tagName: String? = nil) {
        self.name = name
        self.normalizedName = Self.normalizedKey(for: name)
        self.tagName = tagName
    }
    
    // MARK: Static Methods
    
    /// The identity fold: lowercase + collapse whitespace — one folding rule for "same player".
    internal static func normalizedKey(for displayName: String) -> String {
        PlayerName.folded(displayName).lowercased()
    }

    /// The identity a raw **seat tag** resolves to, or nil for the absence of a player (`"?"`/empty
    /// — D9′). Extracted when D61′'s guard needed the answer without creating a row — one spelling.
    internal static func identity(forTag rawTag: String) -> String? {
        let display = PlayerName.displayForm(of: rawTag)
        guard !display.isEmpty, display != RosterSummary.unknownTag else { return nil }
        return normalizedKey(for: display)
    }

    /// Whether two seat tags name one player — the app's one spelling of "seats collide" (D61′).
    /// Identities, not strings ("Lopez, Ruy" == "Ruy Lopez"); nil never collides (two unknowns are
    /// two absences, or every all-unknown import would refuse every edit).
    internal static func seatsNameOnePlayer(_ one: String, _ other: String) -> Bool {
        guard let oneIdentity = identity(forTag: one),
              let otherIdentity = identity(forTag: other) else { return false }
        return oneIdentity == otherIdentity
    }
}
