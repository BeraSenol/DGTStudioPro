import Foundation
import SwiftData

/// A player identity, materialized from the white/black tags of Library
/// games (M-prs.1, Decision D9′).
///
/// **Machine-managed registry**: rows are created exclusively by
/// `PGNStore.resolvePlayer(named:)` — never by views, never by an
/// initializer call outside the store. There is no user CRUD in the POC
/// (no rename, merge, or delete); rename/aliases are the future feature
/// that justifies having a model here at all instead of derived grouping.
///
/// **Identity is `normalizedName`** — the display form lowercased with
/// whitespace collapsed, the same folding the content hash applies to
/// name fields. Stored (denormalized next to `name`) because
/// case-insensitive equality is expressible neither in `#Unique` nor in
/// a `#Predicate` over the display string; the resolver owns both fields,
/// so they can't drift. Diacritics are deliberately preserved ("Bücher"
/// and "Bucher" are different players): we fold case and whitespace only.
/// `name` keeps the first-seen display casing.
///
/// Stats and ratings are deliberately **not** stored here — they're pure
/// folds over the linked games (M-prs.2), recomputed on read, so there is
/// no denormalized state to rot (the `refreshHash` lesson, applied in
/// advance).
@Model
internal final class Player: Identifiable {
    
    // MARK: Stored Properties
    
    /// First-seen display form ("Ruy Lopez"), produced by
    /// `PlayerName.displayForm(of:)` from whichever raw tag created the row.
    internal var name: String

    /// The identity key — see the type comment. Written only alongside
    /// `name` in `init`.
    internal var normalizedName: String

    /// First-seen **tag form** ("Lopez, Ruy") — D29′, D23′'s "no inverse,
    /// remember instead" made real. The New Game seat picker inserts this,
    /// never `name`: a seat field is an editor over a tag (D24′ exports it
    /// byte for byte), and deriving tag form back out of a display form is
    /// undecidable. Whitespace rides `PlayerName.folded` (runs collapse);
    /// comma structure, casing, and diacritics are preserved verbatim.
    /// First-seen wins, like `name`'s casing — a later comma-form sighting
    /// of a row created from free text does *not* upgrade it; one rule, not
    /// two. Optional: rows predating the field carry nil until
    /// `backfillPlayerTagNames()` heals them from their earliest linked
    /// game; an orphaned pre-schema row (no links) stays nil and readers
    /// fall back to `name`.
    internal var tagName: String?

    // No creation timestamp, deliberately (D41′). One lived here, assigned in
    // `init` and read by nothing in the app — `SmartTag` has one because
    // `ContentView` sorts the sidebar by it, and this was that shape copied
    // without the consumer. The question it looks like it answers — "since
    // when have I played this person?" — belongs to `PlayerStats.firstPlayed`,
    // which folds game dates: a row's mint time is when the game was
    // *imported*, so for a back-filled archive it names the wrong day
    // entirely. Re-adding it needs a reader first.

    // MARK: Relationships
    
    /// Inverses of `PGN.whitePlayer` / `PGN.blackPlayer`. `.nullify` so a
    /// (future) player deletion strands no games — they fall back to their
    /// string tags, exactly like rows that predate the schema.
    @Relationship(deleteRule: .nullify, inverse: \PGN.whitePlayer)
    internal var whiteGames: [PGN] = []
    
    @Relationship(deleteRule: .nullify, inverse: \PGN.blackPlayer)
    internal var blackGames: [PGN] = []
    
    // MARK: Computed Properties
    
    internal var id: PersistentIdentifier { persistentModelID }
    
    // MARK: Initializers
    
    /// `name` must already be in display form — the resolver converts raw
    /// tags via `PlayerName.displayForm(of:)` before reaching here.
    /// `tagName` is the whitespace-folded raw tag (D29′); the resolver is
    /// the only production caller and always supplies it — the default
    /// exists for fixtures that construct uninserted rows.
    internal init(name: String, tagName: String? = nil) {
        self.name = name
        self.normalizedName = Self.normalizedKey(for: name)
        self.tagName = tagName
    }
    
    // MARK: Static Methods
    
    /// The identity fold: lowercase + collapse all whitespace runs. Kept
    /// byte-compatible in spirit with `PGNStore`'s hash normalization of
    /// name fields — one folding rule for "same player", not two.
    internal static func normalizedKey(for displayName: String) -> String {
        PlayerName.folded(displayName).lowercased()
    }

    /// The identity a raw **seat tag** resolves to, or `nil` when the tag is
    /// the *absence* of a player rather than a player (D61′).
    ///
    /// `normalizedKey(for:)` one function up answers "what is this display
    /// name's identity" and will happily fold `"?"` into a key. This answers
    /// the question a caller holding a PGN tag actually has: *is there a player
    /// here at all, and if so which one* — which needs the display transform
    /// (D23′, so `"Lopez, Ruy"` and `"Ruy Lopez"` are one identity) and the
    /// placeholder rule (D9′, so `"?"` and empty are no player, never a player
    /// named `"?"`).
    ///
    /// **Extracted because a second caller appeared, not on principle.**
    /// `PGNStore.resolvePlayer(named:)` had these three lines inline and was
    /// the only place that knew them; D61′'s seat guard needs the same answer
    /// *without creating a row*, and restating the rule in a view is how two
    /// spellings of "same player" start. The resolver now calls this, so there
    /// is still exactly one.
    internal static func identity(forTag rawTag: String) -> String? {
        let display = PlayerName.displayForm(of: rawTag)
        guard !display.isEmpty, display != RosterSummary.unknownTag else { return nil }
        return normalizedKey(for: display)
    }

    /// Whether two seat tags name a single player — the app's one spelling of
    /// "these seats collide". D61′ for the rule, its scope, and why the import
    /// door is deliberately exempt.
    ///
    /// Two traps live in these three lines rather than in the anchor. A raw
    /// `!=` compiles, reads correctly, and is wrong: `"Lopez, Ruy"` and `"Ruy
    /// Lopez"` are one player under D23′, so string comparison fails in the
    /// direction that looks most like the guard working. And nil must return
    /// `false` rather than comparing equal — two unknown seats are two absences
    /// (D9′), and treating them as one player would refuse every edit to a
    /// both-seats-unknown game, which is the commonest imported shape.
    internal static func seatsNameOnePlayer(_ one: String, _ other: String) -> Bool {
        guard let oneIdentity = identity(forTag: one),
              let otherIdentity = identity(forTag: other) else { return false }
        return oneIdentity == otherIdentity
    }
}
