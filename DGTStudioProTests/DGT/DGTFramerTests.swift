//
//  DGTFramerTests.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import Testing
@testable import DGTStudioPro

/// Robustness tests for the DGT receiver state machine, in the same spirit as
/// `UCIProtocolTests`: the framer is the one piece of the stack that sees raw,
/// arbitrarily-chunked, possibly-corrupt bytes off the serial line, so it is
/// exercised against split frames, leading garbage, partial tails, back-to-
/// back frames, zero-payload messages, and corrupt/oversized lengths.
@Suite("DGT Framer")
struct DGTFramerTests {
    
    // MARK: Helpers
    
    /// Builds the on-wire bytes for a frame: message byte, 14-bit length as two
    /// 7-bit bytes (`length = payload.count + 3`), then the payload.
    private static func wire(message: UInt8, payload: [UInt8]) -> [UInt8] {
        let total = payload.count + 3
        return [message, UInt8((total >> 7) & 0x7F), UInt8(total & 0x7F)] + payload
    }
    
    private static let fieldUpdate = wire(message: 0x8E, payload: [0x0C, 0x01]) // e2 → wP-ish
    private static let boardDump   = wire(message: 0x86, payload: [UInt8](repeating: 0, count: 64))
    
    // MARK: Whole Frames
    
    @Test func decodesASingleCompleteFrame() {
        var framer = DGTFramer()
        let frames = framer.ingest(Self.fieldUpdate)
        #expect(frames == [DGTFrame(message: 0x8E, data: [0x0C, 0x01])])
    }
    
    @Test func zeroPayloadMessageCompletesImmediately() {
        // length == 3 → no payload; the frame closes on the length-low byte.
        var framer = DGTFramer()
        let frames = framer.ingest([0x40 | 0x80, 0x00, 0x03]) // arbitrary MSB-set id
        #expect(frames.count == 1)
        #expect(frames.first?.data.isEmpty == true)
    }
    
    @Test func backToBackFramesInOneChunkBothEmit() {
        var framer = DGTFramer()
        let frames = framer.ingest(Self.fieldUpdate + Self.fieldUpdate)
        #expect(frames.count == 2)
        #expect(frames.allSatisfy { $0.message == 0x8E })
    }
    
    // MARK: Splitting
    
    @Test func frameSplitAcrossIngestsResumes() {
        var framer = DGTFramer()
        let bytes = Self.boardDump
        let mid = bytes.count / 2
        
        let first = framer.ingest(Array(bytes[..<mid]))
        #expect(first.isEmpty, "no frame should complete from the first half")
        
        let second = framer.ingest(Array(bytes[mid...]))
        #expect(second.count == 1)
        #expect(second.first?.message == 0x86)
        #expect(second.first?.data.count == 64)
    }
    
    @Test func byteAtATimeYieldsExactlyOneFrame() {
        var framer = DGTFramer()
        var completed: [DGTFrame] = []
        for byte in Self.fieldUpdate {
            if let frame = framer.ingest(byte) { completed.append(frame) }
        }
        #expect(completed == [DGTFrame(message: 0x8E, data: [0x0C, 0x01])])
    }
    
    @Test func partialFrameLeavesNothingPending() {
        var framer = DGTFramer()
        let frames = framer.ingest(Array(Self.fieldUpdate.dropLast()))
        #expect(frames.isEmpty)
    }
    
    // MARK: Garbage / Resynchronization
    
    @Test func leadingGarbageIsSkipped() {
        var framer = DGTFramer()
        // Bytes without the MSB set are noise until a real message byte arrives.
        let frames = framer.ingest([0x00, 0x12, 0x7F] + Self.fieldUpdate)
        #expect(frames == [DGTFrame(message: 0x8E, data: [0x0C, 0x01])])
    }
    
    @Test func framerRecoversAfterAGarbageGap() {
        var framer = DGTFramer()
        _ = framer.ingest(Self.fieldUpdate)        // clean frame
        _ = framer.ingest([0x00, 0x01, 0x02])      // junk between frames
        let frames = framer.ingest(Self.fieldUpdate) // must still frame this one
        #expect(frames.count == 1)
        #expect(frames.first?.message == 0x8E)
    }
    
    @Test func oversizedLengthIsRejectedAndResyncs() {
        var framer = DGTFramer()
        // A corrupt length claiming a huge payload: hi=0x7F, lo=0x7F → 16383.
        let bogus = framer.ingest([0x86, 0x7F, 0x7F])
        #expect(bogus.isEmpty, "oversized frame must not begin buffering")
        
        // The framer should be back in sync and able to read the next real frame.
        let frames = framer.ingest(Self.fieldUpdate)
        #expect(frames.count == 1)
        #expect(frames.first?.message == 0x8E)
    }
}
