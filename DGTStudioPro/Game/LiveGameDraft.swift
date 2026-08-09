import Foundation

/// The crash-safety snapshot (Decision #2), written after every committed ply and every
/// result/roster change. A JSON sidecar, not a SwiftData model: singular, must never surface in
/// Library fetches, and human-readable when debugging a failed resume.
internal struct LiveGameDraft: Equatable, Codable, Sendable {

    // MARK: Static Constants

    /// Bump on breaking changes. **Additive optional fields are not breaking** (D28′): synthesized
    /// Codable reads a missing key as nil — optional fields only (D36′'s limit).
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
