import Foundation

/// The crash-safety snapshot of an in-progress live game (M4, Decision #2) —
/// a pure `Codable` value written to disk after every committed ply and
/// every result/roster change, so an app quit or crash mid-game never loses
/// the game.
///
/// Deliberately a JSON sidecar, not a SwiftData model: the draft is singular
/// by invariant (one live game at a time), needs no queries or migrations,
/// must never surface in Library fetches, and a human-readable file is
/// trivially inspectable when debugging a failed resume. Revisit only if
/// drafts ever become plural.
///
/// This struct *is* the on-disk schema, which is why the roster is flattened
/// into named fields rather than embedding `LiveGame.Roster`: renaming an
/// internal property must never silently change the JSON contract. Two
/// fields go beyond the bare minimum so the snapshot stays faithful to
/// everything `LiveGame` can represent: `startFEN` (the model supports
/// custom starts; a draft that can't say where the game began can't resume
/// it) and `ruleSet` (always FIDE in v1, but dropping it would make a future
/// rule set silently resume wrong). `schemaVersion` guards evolution — a
/// missing or unknown version is treated as corrupt, never guessed at.
///
/// Conversion to and from the live model lives in `LiveGame+Draft.swift`
/// (the model owns its data); this file stays free of `@MainActor` types so
/// its coding tests run nonisolated.
internal struct LiveGameDraft: Equatable, Codable, Sendable {

    // MARK: Static Constants

    /// The schema this build reads and writes. Bump on any breaking change
    /// to the fields below. **Additive optional fields are not breaking**
    /// (recorded with D28′, which added `board`): synthesized `Codable`
    /// reads a missing key as nil, and `JSONDecoder` ignores unknown keys,
    /// so version 1 files and builds interoperate in both directions — a
    /// bump would have declared every pre-M2 mid-game draft corrupt for a
    /// field whose absence means exactly what nil means.
    internal static let currentSchemaVersion = 1

    // MARK: Stored Properties

    internal let schemaVersion: Int

    /// FEN of the position the game started from (`states[0]`).
    internal let startFEN: String
    internal let ruleSet: DGTRuleSet

    // Roster, flattened — see the type doc for why these aren't `Roster`.
    internal let event: String
    internal let site: String
    internal let date: Date?
    internal let round: Int?
    internal let white: String
    internal let black: String
    /// The board's `[Board "…"]` identity (D28′). Optional and additive:
    /// absent in version-1 files written before M2, which decode to nil —
    /// see `currentSchemaVersion` for why that is not a schema break.
    internal let board: String?

    /// The SAN transcript, oldest first — the replay source for resume.
    internal let sanMoves: [String]
    internal let result: GameResult

    internal let startedAt: Date
    internal let updatedAt: Date

    // MARK: Coding

    /// Encoder matching the draft's on-disk conventions: ISO 8601 dates and
    /// pretty, key-sorted output so the file is diffable and inspectable.
    /// Fresh instances per call — `JSONEncoder` isn't `Sendable`, so a shared
    /// static would not be concurrency-safe.
    internal static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Decoder counterpart of `encoder()`.
    internal static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
