//
//  CastlingRightsTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 09/06/2026.
//

import Testing
import Foundation
@testable import DGTStudioPro

/// Coverage for `CastlingRights` — the four-bit castling-availability set
/// threaded through `GameState` and serialized into FEN. The bit layout
/// (`K=1, Q=2, k=4, q=8`) and the `fen` rendering are a tested contract: FEN
/// parsing and the move generator both depend on it. Pure value type
/// (`Equatable`/`Hashable`/`Codable`/`Sendable`), so the suite is not
/// `@MainActor`.
///
/// One behaviour worth pinning explicitly: the no-argument `init()` grants
/// **all** rights (a fresh game starts fully castle-able), not none — the
/// opposite of what the `0`-valued `.none` might suggest.
@Suite("Castling Rights")
struct CastlingRightsTests {
    
    // MARK: Constants
    
    @Test func noneAndAllConstants() {
        #expect(CastlingRights.none.rawValue == 0)
        #expect(CastlingRights.all.rawValue == 0b1111)
        
        #expect(CastlingRights.none.fen == "-")
        #expect(CastlingRights.all.fen == "KQkq")
        
        let all = CastlingRights.all
        #expect(all.whiteKingSide && all.whiteQueenSide && all.blackKingSide && all.blackQueenSide)
        
        let none = CastlingRights.none
        #expect(!none.whiteKingSide && !none.whiteQueenSide && !none.blackKingSide && !none.blackQueenSide)
    }
    
    /// The default initializer grants all four rights — the starting-game state.
    @Test func defaultInitGrantsAllRights() {
        #expect(CastlingRights() == .all)
    }
    
    // MARK: Masks
    
    /// Each `(color, side)` maps to exactly one bit, in the documented layout.
    @Test func maskForEachColorSideIsASingleBit() {
        #expect(CastlingRights.mask(for: .white, .kingSide).rawValue  == 0b0001)
        #expect(CastlingRights.mask(for: .white, .queenSide).rawValue == 0b0010)
        #expect(CastlingRights.mask(for: .black, .kingSide).rawValue  == 0b0100)
        #expect(CastlingRights.mask(for: .black, .queenSide).rawValue == 0b1000)
        
        #expect(CastlingRights.mask(for: .white, .kingSide).fen  == "K")
        #expect(CastlingRights.mask(for: .white, .queenSide).fen == "Q")
        #expect(CastlingRights.mask(for: .black, .kingSide).fen  == "k")
        #expect(CastlingRights.mask(for: .black, .queenSide).fen == "q")
    }
    
    // MARK: has
    
    @Test func hasReflectsTheUnderlyingBits() {
        let all = CastlingRights.all
        #expect(all.has(.white, .kingSide))
        #expect(all.has(.white, .queenSide))
        #expect(all.has(.black, .kingSide))
        #expect(all.has(.black, .queenSide))
        
        let none = CastlingRights.none
        #expect(!none.has(.white, .kingSide))
        #expect(!none.has(.black, .queenSide))
        
        // A single right is present in isolation; the others are not.
        let whiteKing = CastlingRights.mask(for: .white, .kingSide)
        #expect(whiteKing.has(.white, .kingSide))
        #expect(!whiteKing.has(.white, .queenSide))
        #expect(!whiteKing.has(.black, .kingSide))
    }
    
    // MARK: fen Rendering
    
    /// `fen` emits set bits in fixed `KQkq` order, and `-` when empty.
    @Test func fenRendersSetBitsInOrder() {
        #expect(CastlingRights(rawValue: 0b0000).fen == "-")
        #expect(CastlingRights(rawValue: 0b1111).fen == "KQkq")
        #expect(CastlingRights(rawValue: 0b0001).fen == "K")
        #expect(CastlingRights(rawValue: 0b0011).fen == "KQ")   // both white
        #expect(CastlingRights(rawValue: 0b1100).fen == "kq")   // both black
        #expect(CastlingRights(rawValue: 0b0101).fen == "Kk")   // both kingside
        #expect(CastlingRights(rawValue: 0b1010).fen == "Qq")   // both queenside
    }
    
    // MARK: revoke
    
    /// `revoke` clears exactly the supplied bits, leaving the rest intact.
    @Test func revokeClearsSpecifiedRights() {
        var rights = CastlingRights.all
        rights.revoke(.mask(for: .white, .kingSide))
        
        #expect(!rights.whiteKingSide)
        #expect(rights.whiteQueenSide)
        #expect(rights.blackKingSide)
        #expect(rights.blackQueenSide)
        #expect(rights.rawValue == 0b1110)
        #expect(rights.fen == "Qkq")
    }
    
    /// `revokeAll(for:)` clears both sides of one color and leaves the other
    /// color untouched.
    @Test func revokeAllForColorClearsThatColorOnly() {
        var white = CastlingRights.all
        white.revokeAll(for: .white)
        #expect(white.rawValue == 0b1100)
        #expect(white.fen == "kq")
        
        var black = CastlingRights.all
        black.revokeAll(for: .black)
        #expect(black.rawValue == 0b0011)
        #expect(black.fen == "KQ")
    }
    
    // MARK: Codable
    
    @Test(arguments: [
        CastlingRights.none, .all,
        CastlingRights(rawValue: 0b0101), CastlingRights(rawValue: 0b1010),
    ])
    func codableRoundTrips(_ rights: CastlingRights) throws {
        let data = try JSONEncoder().encode(rights)
        let decoded = try JSONDecoder().decode(CastlingRights.self, from: data)
        #expect(decoded == rights)
    }
}
