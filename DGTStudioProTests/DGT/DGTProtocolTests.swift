import Testing
@testable import DGTStudioPro

/// The wire-level contract: command bytes, message IDs, `DGTPiece → Piece` mapping. A hardware
/// contract — the values must match the DGT protocol doc exactly; the compiler can't pin *values*.
@Suite("DGT Protocol Constants & Piece Mapping")
struct DGTCommandTests {
    
    // MARK: Outbound Command Bytes
    
    @Test func commandBytesMatchProtocol() {
        #expect(DGTCommand.sendReset.rawValue              == 0x40)
        #expect(DGTCommand.sendBoard.rawValue              == 0x42)
        #expect(DGTCommand.sendUpdateBoard.rawValue        == 0x44)
        #expect(DGTCommand.returnSerialNumber.rawValue     == 0x45)
        #expect(DGTCommand.sendTrademark.rawValue          == 0x47)
        #expect(DGTCommand.sendHardwareVersion.rawValue    == 0x48)
        #expect(DGTCommand.sendVersion.rawValue            == 0x4D)
        #expect(DGTCommand.returnLongSerialNumber.rawValue == 0x55)
    }
    
    // MARK: Inbound Message IDs
    
    @Test func messageIDsMatchProtocol() {
        #expect(DGTMessage.boardDump.rawValue        == 0x86)
        #expect(DGTMessage.fieldUpdate.rawValue      == 0x8E)
        #expect(DGTMessage.serialNumber.rawValue     == 0x91)
        #expect(DGTMessage.trademark.rawValue        == 0x92)
        #expect(DGTMessage.version.rawValue          == 0x93)
        #expect(DGTMessage.hardwareVersion.rawValue  == 0x96)
        #expect(DGTMessage.longSerialNumber.rawValue == 0xA2)
    }
    
    // MARK: DGT Piece Encoding
    
    /// The full DGT piece table, raw byte → expected app `Piece`. Listed
    /// out by hand (not derived from the same lookup under test) so the
    /// test is an independent statement of the contract, not a tautology.
    private static let pieceTable: [(raw: UInt8, expected: Piece)] = [
        (0,  .empty),
        (1,  .whitePawn),
        (2,  .whiteRook),
        (3,  .whiteKnight),
        (4,  .whiteBishop),
        (5,  .whiteKing),
        (6,  .whiteQueen),
        (7,  .blackPawn),
        (8,  .blackRook),
        (9,  .blackKnight),
        (10, .blackBishop),
        (11, .blackKing),
        (12, .blackQueen),
    ]
    
    @Test func everyDGTPieceMapsToCorrectAppPiece() throws {
        for entry in Self.pieceTable {
            let dgtPiece = try #require(
                DGTPiece(rawValue: entry.raw),
                "DGTPiece must define raw value \(entry.raw)"
            )
            #expect(
                dgtPiece.piece == entry.expected,
                "DGTPiece raw \(entry.raw) mapped to \(dgtPiece.piece), expected \(entry.expected)"
            )
        }
    }
    
    @Test func reorderingTrapIsHeldCorrectly() {
        // The cases most likely to be transposed if the lookup were
        // indexed against the app's PieceType ordering instead of DGT's.
        #expect(DGTPiece.whiteRook.piece.type   == .rook)
        #expect(DGTPiece.whiteKnight.piece.type == .knight)
        #expect(DGTPiece.whiteKing.piece.type   == .king)
        #expect(DGTPiece.whiteQueen.piece.type  == .queen)
        // ...and that colour is preserved across the white/black split at 7.
        #expect(DGTPiece.whitePawn.piece.color == .white)
        #expect(DGTPiece.blackPawn.piece.color == .black)
    }
    
    @Test func emptyDGTSquareIsUnoccupied() {
        #expect(DGTPiece.empty.piece == .empty)
        #expect(DGTPiece.empty.piece.isOccupied == false)
    }
    
    @Test func occupiedDGTPiecesReportOccupied() {
        for entry in Self.pieceTable where entry.raw != 0 {
            let dgtPiece = DGTPiece(rawValue: entry.raw)!
            #expect(dgtPiece.piece.isOccupied, "raw \(entry.raw) should be occupied")
        }
    }
    
    @Test func rawValuesAbove12AreUndefined() {
        // The board should never emit these; if it does we want a nil, not
        // a silent out-of-range read. (Pins that the enum has no stray cases.)
        #expect(DGTPiece(rawValue: 13) == nil)
        #expect(DGTPiece(rawValue: 255) == nil)
    }
}
