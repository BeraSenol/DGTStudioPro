//
//  Player.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

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

    internal var createdAt: Date
    
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
        self.createdAt = .now
    }
    
    // MARK: Static Methods
    
    /// The identity fold: lowercase + collapse all whitespace runs. Kept
    /// byte-compatible in spirit with `PGNStore`'s hash normalization of
    /// name fields — one folding rule for "same player", not two.
    internal static func normalizedKey(for displayName: String) -> String {
        PlayerName.folded(displayName).lowercased()
    }
}
