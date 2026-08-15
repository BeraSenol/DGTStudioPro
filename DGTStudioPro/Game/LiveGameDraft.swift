import Foundation

/// The crash-safety snapshot, written after every committed ply and every
/// result/roster change. A JSON sidecar, not a SwiftData model: singular, must never surface in
/// Library fetches, and human-readable when debugging a failed resume.
struct LiveGameDraft: Equatable, Codable, Sendable {

    // MARK: Static Constants

    /// Bump on breaking changes. **Additive optional fields are not breaking**: synthesized
    /// Codable reads a missing key as nil — optional fields only (the limit).
    static let currentSchemaVersion = 1

    // MARK: Stored Properties

    let schemaVersion: Int

    /// FEN of the position the game started from (`states[0]`).
    let startFEN: String
    let ruleSet: DGTRuleSet

    // Roster, flattened — see the type doc for why these aren't `Roster`.
    let event: String
    let site: String
    let date: Date?
    let round: Int?
    let white: String
    let black: String
    /// The board's `[Board "…"]` identity. Optional and additive:
    /// absent in version-1 files written before M2, which decode to nil —
    /// see `currentSchemaVersion` for why that is not a schema break.
    let board: String?

    /// The SAN transcript, oldest first — the replay source for resume.
    let sanMoves: [String]
    let result: GameResult

    let startedAt: Date
    let updatedAt: Date

    // MARK: Coding

    /// Encoder matching the draft's on-disk conventions: ISO 8601 dates and
    /// pretty, key-sorted output so the file is diffable and inspectable.
    /// Fresh instances per call — `JSONEncoder` isn't `Sendable`, so a shared
    /// static would not be concurrency-safe.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Decoder counterpart of `encoder()`.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
