import Foundation
import Testing
@testable import DGTStudioPro

/// Coding tests for the draft schema (M4.1): encode/decode round-trips
/// preserve every field (including the optionals), and the on-disk
/// conventions hold — ISO 8601 dates, pretty-printed, key-sorted JSON.
///
/// `LiveGameDraft` is a `Sendable` value type with no `@MainActor`
/// references (by design — see its type doc), so this suite runs
/// nonisolated.
@Suite("LiveGame Draft")
struct LiveGameDraftTests {

    /// Whole seconds on purpose: the ISO 8601 strategy drops fractional
    /// seconds, so only whole-second dates survive a round-trip exactly.
    /// This instant is 2025-06-15T15:06:40Z.
    private static let instant = Date(timeIntervalSince1970: 1_750_000_000)

    private func sampleDraft(
        date: Date? = instant,
        round: Int? = 3,
        board: String? = "DGT 3000448278"
    ) -> LiveGameDraft {
        LiveGameDraft(
            schemaVersion: LiveGameDraft.currentSchemaVersion,
            startFEN: FEN(GameState.starting).string,
            ruleSet: .fide,
            event: "Club Night",
            site: "Home",
            date: date,
            round: round,
            white: "Wendy",
            black: "Blake",
            board: board,
            sanMoves: ["e4", "e5", "Nf3"],
            result: .ongoing,
            startedAt: Self.instant,
            updatedAt: Self.instant
        )
    }

    @Test func roundTripPreservesEveryField() throws {
        let original = sampleDraft()

        let data = try LiveGameDraft.encoder().encode(original)
        let decoded = try LiveGameDraft.decoder().decode(LiveGameDraft.self, from: data)

        #expect(decoded == original)
    }

    /// The optionals (date, round, board) must survive as absent — a draft
    /// for a casual game with no round shouldn't resurrect with invented
    /// values.
    @Test func roundTripPreservesNilOptionals() throws {
        let original = sampleDraft(date: nil, round: nil, board: nil)

        let data = try LiveGameDraft.encoder().encode(original)
        let decoded = try LiveGameDraft.decoder().decode(LiveGameDraft.self, from: data)

        #expect(decoded == original)
        #expect(decoded.date == nil)
        #expect(decoded.round == nil)
        #expect(decoded.board == nil)
    }

    /// The schema stance, pinned: a version-1 file written *before* the
    /// `board` field existed — no `board` key at all — still decodes, with
    /// nil. If adding a field ever breaks this, `currentSchemaVersion` owes
    /// a bump and this test the update.
    @Test func preBoardVersionOneFileDecodesWithNilBoard() throws {
        let pre = sampleDraft(board: nil)
        let data = try LiveGameDraft.encoder().encode(pre)
        // Synthesized Codable omits a nil optional's key entirely, so this
        // encoding *is* a pre-M2 file — assert that premise, then decode it.
        #expect(!String(decoding: data, as: UTF8.self).contains("\"board\""))

        let decoded = try LiveGameDraft.decoder().decode(LiveGameDraft.self, from: data)

        #expect(decoded.board == nil)
        #expect(decoded == pre)
    }

    /// Dates are ISO 8601 in the file — human-readable and timezone-stable,
    /// per the sidecar's "inspectable when debugging" charter.
    @Test func encodingUsesISO8601Dates() throws {
        let data = try LiveGameDraft.encoder().encode(sampleDraft())
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("2025-06-15T15:06:40Z"))
    }

    /// Pretty-printed, key-sorted output keeps the file diffable across
    /// saves — the same draft always serializes to the same bytes.
    @Test func encodingIsPrettyAndKeySorted() throws {
        let data = try LiveGameDraft.encoder().encode(sampleDraft())
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("\n"))
        let black = try #require(json.range(of: "\"black\""))
        let white = try #require(json.range(of: "\"white\""))
        #expect(black.lowerBound < white.lowerBound)
    }
}
