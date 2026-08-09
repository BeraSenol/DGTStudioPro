/// One received DGT message. The framer is semantics-free — it carries the raw message byte
/// (even unrecognized ones), which is what makes it resumable and testable.
internal struct DGTFrame: Equatable, Sendable {
    /// The response byte that opened the frame (MSB set, e.g. `0x86`).
    internal let message: UInt8
    /// The payload bytes (frame length minus the 3 header bytes). May be empty.
    internal let data: [UInt8]
}

/// Incremental receiver state machine per the DGT protocol pseudocode: byte 0 is the message
/// byte (MSB set), then two 7-bit length bytes; MSB-based resync skips junk between frames.
/// Holds partial progress across calls — chunk boundaries land anywhere.
internal struct DGTFramer {
    
    // MARK: Configuration
    
    /// The largest real message is the 64-byte board dump; anything claiming much more is a corrupt
    /// length field, not a frame to buffer for.
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
    
    /// Feeds a chunk through the machine, returning frames completed within it; a partial frame is
    /// retained for the next call.
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
