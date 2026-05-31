//
//  DGTFramer.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

/// One fully-received DGT message, sliced out of the byte stream by
/// `DGTFramer`. The framer is deliberately semantics-free: it carries the raw
/// message byte (even one we don't recognize) and the payload bytes that
/// followed it. Interpreting them into a `DGTEvent` is `DGTDecoder`'s job.
///
/// Keeping the message byte raw rather than a `DGTMessage` is what makes the
/// framer robust to unknown/future message IDs — it still frames them
/// correctly, and the decoder (or D2's `dgt` logging) decides what to do.
internal struct DGTFrame: Equatable, Sendable {
    /// The response byte that opened the frame (MSB set, e.g. `0x86`).
    internal let message: UInt8
    /// The payload bytes (frame length minus the 3 header bytes). May be empty.
    internal let data: [UInt8]
}

/// Incremental receiver state machine for the DGT serial protocol.
///
/// This is a faithful, hardware-free implementation of the receiver pseudocode
/// in the DGT Chessboard Communication Protocol. Bytes arrive from the serial
/// reader in arbitrary chunks — split mid-frame, several frames at once, with
/// junk between frames — so framing must be a resumable state machine that
/// holds partial progress across calls, exactly like a UCI line buffer but
/// length-delimited instead of newline-delimited.
///
/// Frame layout on the wire:
/// - byte 0: message/response byte, **MSB set**
/// - byte 1: length high (7 bits)
/// - byte 2: length low (7 bits) — total `length = (hi << 7) | lo`
/// - bytes 3…: `length − 3` payload bytes
///
/// Robustness guarantees (pinned by `DGTFramerTests`):
/// - **Garbage before a frame** (bytes without the MSB set) is skipped while
///   awaiting a message byte.
/// - **Split frames** resume correctly across `ingest` calls.
/// - **Back-to-back frames** in one chunk all emit.
/// - **Zero-payload messages** (`length ≤ 3`) complete immediately.
/// - **Oversized length** (a corrupt length field claiming more payload than
///   any real DGT message) is rejected and the framer resynchronizes rather
///   than buffering unboundedly.
internal struct DGTFramer {
    
    // MARK: Configuration
    
    /// Upper bound on payload size. The largest real DGT message is the board
    /// dump at 64 payload bytes; anything claiming materially more than that is
    /// a corrupt length field, not a frame we should buffer for.
    private static let maxPayloadLength = 256
    
    // MARK: State
    
    private enum State {
        case awaitingMessage
        case lengthHigh
        case lengthLow
        case payload
    }
    
    private var state: State = .awaitingMessage
    private var message: UInt8 = 0
    private var declaredLength = 0
    private var expectedPayload = 0
    private var buffer: [UInt8] = []
    
    // MARK: Initializers
    
    internal init() {}
    
    // MARK: Ingestion
    
    /// Feeds a chunk of received bytes through the state machine, returning any
    /// frames that completed within this chunk (possibly several, possibly
    /// none — a partial frame is retained for the next call).
    internal mutating func ingest(_ bytes: some Sequence<UInt8>) -> [DGTFrame] {
        var frames: [DGTFrame] = []
        for byte in bytes {
            if let frame = ingest(byte) {
                frames.append(frame)
            }
        }
        return frames
    }
    
    /// Feeds a single byte, returning a frame iff that byte completed one.
    internal mutating func ingest(_ byte: UInt8) -> DGTFrame? {
        switch state {
        case .awaitingMessage:
            // Skip stray bytes until a response byte (MSB set) appears.
            if byte & 0x80 != 0 {
                message = byte
                state = .lengthHigh
            }
            return nil
            
        case .lengthHigh:
            declaredLength = Int(byte & 0x7F)
            state = .lengthLow
            return nil
            
        case .lengthLow:
            declaredLength = (declaredLength << 7) | Int(byte & 0x7F)
            buffer.removeAll(keepingCapacity: true)
            
            // length counts the 3 header bytes; a length ≤ 3 carries no payload.
            guard declaredLength > 3 else {
                return completeFrame()
            }
            
            expectedPayload = declaredLength - 3
            
            // Corrupt/oversized length: drop and resynchronize.
            guard expectedPayload <= Self.maxPayloadLength else {
                resync()
                return nil
            }
            
            state = .payload
            return nil
            
        case .payload:
            buffer.append(byte)
            guard buffer.count >= expectedPayload else { return nil }
            return completeFrame()
        }
    }
    
    // MARK: Helpers
    
    private mutating func completeFrame() -> DGTFrame {
        let frame = DGTFrame(message: message, data: buffer)
        resync()
        return frame
    }
    
    private mutating func resync() {
        state = .awaitingMessage
        message = 0
        declaredLength = 0
        expectedPayload = 0
        buffer.removeAll(keepingCapacity: true)
    }
}
