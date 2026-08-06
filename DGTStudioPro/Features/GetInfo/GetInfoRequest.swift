import SwiftData

// MARK: - Request

/// What a Get Info gesture asks for: one subject, named by what it is.
///
/// **An enum, and a wrapper rather than a bare `PersistentIdentifier` — the
/// trap this whole file is arranged around.** `openWindow(value:)` routes by
/// the value's *type*, and the main `WindowGroup` already claims
/// `PersistentIdentifier`; a second group over it would silently turn "open a
/// game from the Library" into "open a graph" (D46′, first instance). One enum
/// and one scene rather than three of each pays that cost once and tabs the
/// three info windows with each other rather than behind a board.
///
/// `.live` carries nothing — a live game has no identifier until it archives.
/// Hence an enum and not a struct with an optional id, which would make "no
/// game" and "the live game" the same value. D53′.
internal enum GetInfoRequest: Codable, Hashable, Sendable {

    /// An archived game, from the Library or the Board's review branch.
    case game(PersistentIdentifier)

    /// The game currently being recorded. Reached from the Board only, and
    /// only while one is in progress.
    case live

    /// A player, named by `Player.normalizedName`.
    ///
    /// A key, not a `PersistentIdentifier`: Players' view modes render
    /// `PlayerStats`, whose `ID` *is* the normalized key, so no row on that
    /// screen holds a `Player` to take an identifier from. D40′ rides along —
    /// a linkless row appears in no view mode, so no key here names an orphan.
    case player(key: String)
}
