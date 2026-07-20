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
    /// `PGN.displayPlayerName(_:)` from whichever raw tag created the row.
    internal var name: String
    
    /// The identity key — see the type comment. Written only alongside
    /// `name` in `init`.
    internal var normalizedName: String
    
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
    /// tags via `PGN.displayPlayerName(_:)` before reaching here.
    internal init(name: String) {
        self.name = name
        self.normalizedName = Self.normalizedKey(for: name)
        self.createdAt = .now
    }
    
    // MARK: Static Methods
    
    /// The identity fold: lowercase + collapse all whitespace runs. Kept
    /// byte-compatible in spirit with `PGNStore`'s hash normalization of
    /// name fields — one folding rule for "same player", not two.
    internal static func normalizedKey(for displayName: String) -> String {
        displayName
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
