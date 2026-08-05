import Testing
@testable import DGTStudioPro

/// Decode-layer tests. The headline case is the start-position board dump
/// decoding to `Position.starting` *after* the coordinate transform — the
/// roadmap's named "first decoder test". The dump fixture is built by hand in
/// DGT field order with DGT piece codes, so it is an independent statement of
/// the wire format, not a re-derivation of the code under test.
@Suite("DGT Decoder")
struct DGTDecoderTests {
    
    // MARK: Fixtures
    
    /// Standard start position as a board dump payload, in DGT field order
    /// (a8 = field 0 … h1 = field 63), using DGT piece codes
    /// (empty 0; white P1 R2 N3 B4 K5 Q6; black P7 R8 N9 B10 K11 Q12).
    private static let startPositionDumpPayload: [UInt8] = {
        var bytes = [UInt8](repeating: 0, count: 64)
        // Fields 0–7: black back rank a8…h8 = r n b q k b n r
        let blackBack: [UInt8] = [8, 9, 10, 12, 11, 10, 9, 8]
        // Fields 56–63: white back rank a1…h1 = R N B Q K B N R
        let whiteBack: [UInt8] = [2, 3, 4, 6, 5, 4, 3, 2]
        for file in 0..<8 {
            bytes[0 + file]  = blackBack[file] // rank 8
            bytes[8 + file]  = 7               // rank 7: black pawns
            bytes[48 + file] = 1               // rank 2: white pawns
            bytes[56 + file] = whiteBack[file] // rank 1
        }
        return bytes
    }()
    
    private func frame(_ message: UInt8, _ data: [UInt8]) -> DGTFrame {
        DGTFrame(message: message, data: data)
    }
    
    // MARK: Board Dump
    
    @Test func startPositionDumpDecodesToStartingPosition() throws {
        let event = try #require(
            DGTDecoder.decode(frame(0x86, Self.startPositionDumpPayload))
        )
        guard case .boardDump(let position) = event else {
            Issue.record("Expected .boardDump, got \(event)")
            return
        }
        #expect(position == .starting)
    }
    
    @Test func emptyBoardDumpDecodesToEmptyPosition() throws {
        let event = try #require(
            DGTDecoder.decode(frame(0x86, [UInt8](repeating: 0, count: 64)))
        )
        #expect(event == .boardDump(.empty))
    }
    
    @Test func boardDumpPlacesIndividualPieceOnCorrectSquare() throws {
        // A lone white king on DGT field 60 should land on app square e1.
        var payload = [UInt8](repeating: 0, count: 64)
        payload[60] = 5 // white king
        let event = try #require(DGTDecoder.decode(frame(0x86, payload)))
        guard case .boardDump(let position) = event else {
            Issue.record("Expected .boardDump, got \(event)")
            return
        }
        #expect(position[Squares.e1] == .whiteKing)
    }
    
    @Test func boardDumpWithWrongLengthReturnsNil() {
        #expect(DGTDecoder.decode(frame(0x86, [UInt8](repeating: 0, count: 63))) == nil)
        #expect(DGTDecoder.decode(frame(0x86, [UInt8](repeating: 0, count: 65))) == nil)
        #expect(DGTDecoder.decode(frame(0x86, [])) == nil)
    }
    
    @Test func boardDumpWithOutOfRangePieceCodeReturnsNil() {
        var payload = [UInt8](repeating: 0, count: 64)
        payload[0] = 13 // no such DGT piece
        #expect(DGTDecoder.decode(frame(0x86, payload)) == nil)
    }
    
    // MARK: Field Update
    
    @Test func fieldUpdateDecodesSquareAndPiece() throws {
        // DGT field 52 = app square e2; piece code 1 = white pawn.
        let event = try #require(DGTDecoder.decode(frame(0x8E, [52, 1])))
        #expect(event == .fieldUpdate(square: Squares.e2, piece: .whitePawn))
    }
    
    @Test func fieldUpdateToEmptyDecodesAsLift() throws {
        let event = try #require(DGTDecoder.decode(frame(0x8E, [52, 0])))
        #expect(event == .fieldUpdate(square: Squares.e2, piece: .empty))
    }
    
    @Test func fieldUpdateWithWrongLengthReturnsNil() {
        #expect(DGTDecoder.decode(frame(0x8E, [52])) == nil)
        #expect(DGTDecoder.decode(frame(0x8E, [52, 1, 0])) == nil)
    }
    
    @Test func fieldUpdateWithOutOfRangeFieldReturnsNil() {
        #expect(DGTDecoder.decode(frame(0x8E, [64, 1])) == nil)
    }
    
    @Test func fieldUpdateWithOutOfRangePieceReturnsNil() {
        #expect(DGTDecoder.decode(frame(0x8E, [52, 13])) == nil)
    }
    
    // MARK: Version
    
    @Test func versionDecodesTwoSevenBitBytes() throws {
        let event = try #require(DGTDecoder.decode(frame(0x93, [1, 5])))
        #expect(event == .version(major: 1, minor: 5))
    }
    
    @Test func hardwareVersionDecodesDistinctly() throws {
        let event = try #require(DGTDecoder.decode(frame(0x96, [2, 0])))
        #expect(event == .hardwareVersion(major: 2, minor: 0))
    }
    
    // MARK: Text Info Messages
    
    @Test func serialNumberDecodesTrimmedAscii() throws {
        let payload = Array("12345\0".utf8)
        let event = try #require(DGTDecoder.decode(frame(0x91, payload)))
        #expect(event == .serialNumber("12345"))
    }
    
    @Test func trademarkDecodesAscii() throws {
        let payload = Array("DGT".utf8)
        let event = try #require(DGTDecoder.decode(frame(0x92, payload)))
        #expect(event == .trademark("DGT"))
    }
    
    @Test func emptyTextMessageReturnsNil() {
        #expect(DGTDecoder.decode(frame(0x91, [])) == nil)
        #expect(DGTDecoder.decode(frame(0x91, [0, 0, 0])) == nil) // NULs only
    }
    
    // MARK: Unknown Messages
    
    @Test func unknownMessageIDReturnsNil() {
        // A framed-but-unrecognized message ID is the decoder's responsibility
        // to ignore (D2 logs the raw byte); it must not trap.
        #expect(DGTDecoder.decode(frame(0xA4, [0x01])) == nil) // lock-state, unhandled
        #expect(DGTDecoder.decode(frame(0xFF, [])) == nil)
    }
}
