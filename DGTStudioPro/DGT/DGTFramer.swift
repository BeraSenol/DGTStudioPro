/// One received DGT message. `message` is the raw byte rather than a `DGTMessage`, which is what
/// keeps the framer semantics-free: an unrecognized ID still frames, and `DGTSerialPort` logs it as
/// "Undecoded frame" instead of dropping it unseen.
struct DGTFrame: Equatable, Sendable {
    /// The response byte that opened the frame - MSB set, e.g. `0x86`.
    let message: UInt8
    /// Frame length minus its 3 header bytes. May be empty.
    let data: [UInt8]
}

/// Incremental receiver: message byte (MSB set), two 7-bit length bytes, then payload. Holds
/// partial progress across calls, because chunk boundaries land anywhere.
///
/// **Only a message byte carries the MSB**, which is why the length is encoded as two 7-bit bytes
/// rather than one - the bit is reserved for marking a frame start. So an MSB-set byte arriving
/// mid-frame means the frame before it was truncated, and `ingest` abandons it there instead of
/// counting on into the next message.
struct DGTFramer {
    
    // MARK: Configuration
    
    /// Headroom over the 64-byte board dump, not a measured maximum: the text messages are
    /// variable-length and nothing here has seen a real trademark banner. Too small would surface
    /// as the Trademark row never filling in, silently.
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
    
    /// Not redundant: the stored properties are private, so the synthesized memberwise init is
    /// private too and `DGTFramer()` would not compile in `DGTSerialPort`.
    init() {}
    
    // MARK: Ingestion
    
    /// Frames completed within this chunk; a partial one is retained for the next call.
    mutating func ingest(_ bytes: some Sequence<UInt8>) -> [DGTFrame] {
        var frames: [DGTFrame] = []
        for byte in bytes {
            if let frame = ingest(byte) {
                frames.append(frame)
            }
        }
        return frames
    }
    
    /// A frame iff this byte completed one.
    mutating func ingest(_ byte: UInt8) -> DGTFrame? {
        // A message byte mid-frame: the frame in progress lost a byte. Drop it and let the switch
        // below open a fresh one here. Without this, the truncated frame closes on this very byte
        // - emitting a bogus frame - and then swallows everything up to the *next* message, which
        // for a board dump is the whole 64-byte payload `DGTConnection` waits on to reach
        // `.connected`. Exhaustive on purpose: a new state has to declare which side it is on.
        if byte & 0x80 != 0 {
            switch state {
            case .awaitingMessage:
                break
            case .lengthHigh, .lengthLow, .payload:
                resync()
            }
        }

        switch state {
        case .awaitingMessage:
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
            
            // Length counts the 3 header bytes, so ≤ 3 carries no payload.
            guard declaredLength > 3 else {
                return completeFrame()
            }
            
            expectedPayload = declaredLength - 3
            
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
