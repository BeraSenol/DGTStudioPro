import SwiftData

// MARK: - Request

/// One Get Info subject. An enum, and a wrapper — `openWindow(value:)` routes by type, and the
/// main group claims `PersistentIdentifier`. `.live` carries nothing: a live game has no id
/// until it archives, and an optional id would make "no game" and "the live game" one value.
internal enum GetInfoRequest: Codable, Hashable, Sendable {

    /// An archived game, from the Library or the Board's review branch.
    case game(PersistentIdentifier)

    /// The game currently being recorded. Reached from the Board only, and
    /// only while one is in progress.
    case live

    /// A player, by `Player.normalizedName` — a key, not an id: the view modes render folds, and a
    /// request must be `Codable` scene state.
    case player(key: String)
}
