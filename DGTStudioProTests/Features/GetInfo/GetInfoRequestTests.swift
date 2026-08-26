import Testing
import Foundation
import SwiftData
@testable import DGTStudioPro

/// Pins the Get Info routing value (M18 Phase 1). `openWindow(value:)` routes on this type's
/// `Codable` + `Hashable` conformances - a case that stops round-tripping stops opening its
/// window, silently, and nothing else in the suite would notice. `@MainActor` for the one
/// test that needs an inserted model's id.
@MainActor
@Suite("Get Info Request")
struct GetInfoRequestTests {

    private static func encodeDecode(_ request: GetInfoRequest) throws -> GetInfoRequest {
        try JSONDecoder().decode(GetInfoRequest.self, from: JSONEncoder().encode(request))
    }

    @Test func liveRoundTripsThroughCodable() throws {
        #expect(try Self.encodeDecode(.live) == .live)
    }

    @Test func playerRoundTripsWithItsKey() throws {
        let request = GetInfoRequest.player(key: "carlsen, magnus")
        #expect(try Self.encodeDecode(request) == request)
    }

    /// The declaration's own claim - ".game proves `PersistentIdentifier` is `Codable`" -
    /// compiled from the side where it would break: a real inserted id, through the encoder.
    @Test func gameRoundTripsWithARealIdentifier() throws {
        let container = try ModelContainer(
            for: PGN.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let pgn = PGN(white: "Alice", black: "Bob", moves: ["e4"], name: "Fixture")
        context.insert(pgn)

        let request = GetInfoRequest.game(pgn.persistentModelID)
        #expect(try Self.encodeDecode(request) == request)
    }

    /// Three cases, three distinct hash identities - the window group's routing depends on
    /// distinct values opening distinct windows.
    @Test func distinctSubjectsHashDistinctly() {
        let requests: Set<GetInfoRequest> = [
            .live,
            .player(key: "alice"),
            .player(key: "bob")
        ]
        #expect(requests.count == 3)
    }
}
