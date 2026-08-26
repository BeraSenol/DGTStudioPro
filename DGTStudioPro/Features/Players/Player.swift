import Foundation
import SwiftData

/// A player identity materialized from seat tags. **Machine-managed**: created only by
/// `PGNStore.resolvePlayer(named:)`. Identity = display form lowercased, whitespace collapsed;
/// diacritics preserved ("Bücher" ≠ "Bucher"); first-seen casing wins. Orphans are collected by
/// every door that can strand one.
///
/// **Filed here by disposition (M18, 26 Aug 2026).** The audits asked whether a `@Model`
/// co-owned by the store belongs in `PGN/` beside its creation door; considered and it stays:
/// D9′ is about *ownership* (store-owned links), not folders, the verification showed the
/// import cycles are not placement-caused, and this is the type the Players destination names
/// on every surface — moving it would file the feature's namesake where the feature never
/// looks. A considered stays closes the item.
@Model
final class Player: Identifiable {
    
    // MARK: Stored Properties
    
    /// First-seen display form, from whichever raw tag created the row.
    var name: String

    /// The identity key; written only alongside `name` in `init`.
    var normalizedName: String

    /// First-seen **tag form** (the "no inverse, remember instead"). The seat pickers
    /// insert this, never `name`; deriving tag form from display form is the forbidden inverse.
    var tagName: String?

    // MARK: Relationships
    
    /// Inverses of `PGN.whitePlayer`/`blackPlayer`; `.nullify` so a deletion strands no games.
    @Relationship(deleteRule: .nullify, inverse: \PGN.whitePlayer)
    var whiteGames: [PGN] = []
    
    @Relationship(deleteRule: .nullify, inverse: \PGN.blackPlayer)
    var blackGames: [PGN] = []
    
    // MARK: Computed Properties
    
    var id: PersistentIdentifier { persistentModelID }
    
    // MARK: Initializers
    
    /// `name` must already be display form; the resolver is the only production caller and always
    /// supplies `tagName` - the default exists for fixtures.
    init(name: String, tagName: String? = nil) {
        self.name = name
        self.normalizedName = Self.normalizedKey(for: name)
        self.tagName = tagName
    }
    
    // MARK: Static Methods
    
    /// The identity fold: lowercase + collapse whitespace - one folding rule for "same player".
    static func normalizedKey(for displayName: String) -> String {
        PlayerName.folded(displayName).lowercased()
    }

    /// The identity a raw **seat tag** resolves to, or nil for the absence of a player (`"?"`/empty).
    /// Extracted when the guard needed the answer without creating a row - one spelling.
    static func identity(forTag rawTag: String) -> String? {
        let display = PlayerName.displayForm(of: rawTag)
        guard !display.isEmpty, display != RosterSummary.unknownTag else { return nil }
        return normalizedKey(for: display)
    }

    /// Whether two seat tags name one player - the app's one spelling of "seats collide".
    /// Identities, not strings ("Lopez, Ruy" == "Ruy Lopez"); nil never collides (two unknowns are
    /// two absences, or every all-unknown import would refuse every edit).
    static func seatsNameOnePlayer(_ one: String, _ other: String) -> Bool {
        guard let oneIdentity = identity(forTag: one),
              let otherIdentity = identity(forTag: other) else { return false }
        return oneIdentity == otherIdentity
    }
}
