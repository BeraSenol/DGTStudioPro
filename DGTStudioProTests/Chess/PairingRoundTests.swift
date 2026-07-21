//
//  PairingRoundTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 21/07/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// The D16′ round-prefill fold. Nonisolated — pure value types, the D10′
/// suite shape. Keys here are already-normalized identity keys (opaque to
/// the fold; resolution is the caller's job and `Player.normalizedKey`'s
/// suite territory).
@Suite("Pairing Round")
struct PairingRoundTests {
    
    private func game(
        white: String?,
        black: String?,
        round: Int?
    ) -> GameRecord {
        GameRecord(
            white: white.map { .init(key: $0, name: $0) },
            black: black.map { .init(key: $0, name: $0) },
            result: .whiteWins,
            endedInMate: false,
            date: nil,
            importedAt: Date(timeIntervalSinceReferenceDate: 0),
            contentHash: UUID().uuidString,
            round: round
        )
    }
    
    @Test func latestRoundPlusOne() {
        let records = [
            game(white: "bera", black: "lorenzo", round: 1),
            game(white: "bera", black: "lorenzo", round: 2)
        ]
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: records) == 3)
    }
    
    /// F9: the pairing is a set — both color assignments count.
    @Test func bothColorAssignmentsCount() {
        let records = [
            game(white: "bera", black: "lorenzo", round: 4),
            game(white: "lorenzo", black: "bera", round: 5)
        ]
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: records) == 6)
    }
    
    /// The argument order can't matter either — same set, same answer.
    @Test func argumentOrderIsIrrelevant() {
        let records = [game(white: "bera", black: "lorenzo", round: 7)]
        #expect(
            PairingRound.nextRound(between: "bera", and: "lorenzo", in: records)
            == PairingRound.nextRound(between: "lorenzo", and: "bera", in: records)
        )
    }
    
    /// F9's other half: a game against a third player never informs this
    /// pairing — the pair's history, not each player's individual maximum.
    @Test func thirdPartyGamesAreIgnored() {
        let records = [
            game(white: "bera", black: "carla", round: 9),
            game(white: "bera", black: "lorenzo", round: 2)
        ]
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: records) == 3)
    }
    
    /// "Latest" is the numeric maximum, not the last game entered — an
    /// old low-round game arriving late must not wind the counter back.
    @Test func maximumWinsRegardlessOfRecordOrder() {
        let records = [
            game(white: "bera", black: "lorenzo", round: 7),
            game(white: "bera", black: "lorenzo", round: 2)
        ]
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: records) == 8)
    }
    
    /// An unresolved seat can't prove the pairing (unknowns never match).
    @Test func unresolvedSeatsNeverMatch() {
        let records = [
            game(white: "bera", black: nil, round: 3),
            game(white: nil, black: "lorenzo", round: 4)
        ]
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: records) == nil)
    }
    
    /// Pairing games with nil rounds contribute nothing to the maximum…
    @Test func nilRoundsDoNotInform() {
        let records = [
            game(white: "bera", black: "lorenzo", round: nil),
            game(white: "bera", black: "lorenzo", round: 3)
        ]
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: records) == 4)
    }
    
    /// …and a pairing with *only* nil rounds has no round history at all.
    @Test func pairingWithOnlyNilRoundsHasNoHistory() {
        let records = [game(white: "bera", black: "lorenzo", round: nil)]
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: records) == nil)
    }
    
    @Test func emptyLibraryHasNoHistory() {
        #expect(PairingRound.nextRound(between: "bera", and: "lorenzo", in: []) == nil)
    }
    
    /// Degenerate but total: querying a player against themselves matches
    /// only records where both seats are that player (the set collapses).
    @Test func selfPairingMatchesOnlySelfGames() {
        let records = [
            game(white: "bera", black: "bera", round: 1),
            game(white: "bera", black: "lorenzo", round: 6)
        ]
        #expect(PairingRound.nextRound(between: "bera", and: "bera", in: records) == 2)
    }
}
