import Foundation
import os

/// The transport seam `DGTConnection` drives (F9): real port below, scripted fakes in tests.
/// **The event stream finishing is the single "port is gone" signal** — teardown cancels it, an
/// unplug does not.
protocol DGTPortProviding: Actor {
    /// Opens the device and returns the decoded event stream; the stream finishes when the port
    /// closes — explicitly, or because the device went away (F1).
    func open(path: String) throws -> AsyncStream<DGTEvent>
    /// Closes the port and finishes the event stream. No-op when not open.
    func close()
    /// Sends a single-byte command to the board.
    func send(_ command: DGTCommand) throws
}

/// Owns the serial fd and turns inbound bytes into decoded `DGTEvent`s — `StockfishEngine`'s
/// analogue. Raw bytes never escape un-decoded: framing (`DGTFramer`) and semantics
/// (`DGTDecoder`) live here, so the @MainActor connection only sees events. Chunk order is
/// preserved end to end — two swapped chunks would desync the framer (F2).
actor DGTSerialPort: DGTPortProviding {
    
    // MARK: Logging
    
    private static let logger = AppLog.logger(.dgt)
    
    // MARK: Errors
    
    enum PortError: Error, Equatable {
        case openFailed(errno: Int32)
        case configureFailed(errno: Int32)
        case alreadyOpen
        case notOpen
        case writeFailed(errno: Int32)
    }
    
    // MARK: State
    
    private var fileDescriptor: Int32 = -1
    private var fileHandle: FileHandle?
    private var framer = DGTFramer()
    private var eventContinuation: AsyncStream<DGTEvent>.Continuation?
    
    /// Raw chunks in arrival order (F2); finished on EOF/read-error (F1) or `close()`.
    private var byteContinuation: AsyncStream<Data>.Continuation?
    
    /// The single actor-isolated consumer; `readSourceEnded()` decides whether an end was deliberate.
    private var readLoopTask: Task<Void, Never>?
    
    init() {}
    
    /// Whether the port holds a file descriptor. **The app target's one symbol with no consumer,
    /// kept by decision** (not D41′'s disposition — no better sibling answers this question).
    var isOpen: Bool { fileDescriptor >= 0 }
    
    // MARK: Open / Close
    
    /// Opens, configures, starts the ordered pipeline, returns decoded events (stream finishes when
    /// the port closes — F1).
    func open(path: String) throws -> AsyncStream<DGTEvent> {
        guard fileDescriptor < 0 else {
            Self.logger?.error("Serial open ignored, port already open")
            throw PortError.alreadyOpen
        }
        
        let fd = path.withCString { Darwin.open($0, O_RDWR | O_NOCTTY | O_NONBLOCK) }
        guard fd >= 0 else {
            let err = errno
            Self.logger?.error("Serial open failed: path='\(path, privacy: .public)' errno=\(err, privacy: .public)")
            throw PortError.openFailed(errno: err)
        }
        
        do {
            try configure(fd)
        } catch {
            Darwin.close(fd)
            throw error
        }
        
        fileDescriptor = fd
        framer = DGTFramer()
        
        // The ordered byte pipeline (F2) — see the type doc.
        let (bytes, byteContinuation) = AsyncStream.makeStream(of: Data.self)
        self.byteContinuation = byteContinuation
        
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        // Raw `read(2)` instead of `availableData` (F1). The closure captures no `self` — it only
        // bridges bytes and the end signal.
        handle.readabilityHandler = { handle in
            var buffer = [UInt8](repeating: 0, count: 512)
            let count = Darwin.read(handle.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                byteContinuation.yield(Data(buffer[0..<count]))
            } else if count == 0 {
                // EOF — device gone. Stop the source, end the pipeline.
                handle.readabilityHandler = nil
                byteContinuation.finish()
            } else if errno == EAGAIN || errno == EINTR {
                // Spurious wakeup — the next callback retries.
            } else {
                // Fatal read error (ENXIO/EIO after unplug) — same exit.
                handle.readabilityHandler = nil
                byteContinuation.finish()
            }
        }
        fileHandle = handle
        
        // One long-lived actor-isolated consumer, in stream order. Created before `eventContinuation`
        // exists would be a bug — a Task in actor-isolated code cannot run until this method suspends.
        readLoopTask = Task {
            for await chunk in bytes {
                ingest(chunk)
            }
            readSourceEnded()
        }
        
        Self.logger?.info("Opened serial port '\(path, privacy: .public)' fd=\(fd)")
        
        return AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
    
    /// Closes, finishes the event stream, resets. No-op when not open.
    func close() {
        guard fileDescriptor >= 0 else { return }
        Self.logger?.info("Closing serial port fd=\(self.fileDescriptor)")
        
        fileHandle?.readabilityHandler = nil
        fileHandle = nil
        Darwin.close(fileDescriptor)
        fileDescriptor = -1
        
        // End the byte pipeline; the read loop drains and stands down (late frames yield into a
        // finished stream, harmlessly).
        byteContinuation?.finish()
        byteContinuation = nil
        readLoopTask = nil
        
        eventContinuation?.finish()
        eventContinuation = nil
        framer = DGTFramer()
    }
    
    /// Byte stream finished. `close()`-initiated → nothing to do; otherwise the device vanished
    /// (F1): close ourselves, which finishes the *event* stream — the signal the connection keys on.
    private func readSourceEnded() {
        guard fileDescriptor >= 0 else { return }
        Self.logger?.error("Serial read source ended (device vanished or read failed), closing port")
        close()
    }
    
    // MARK: Write
    
    /// Sends a single-byte command to the board.
    func send(_ command: DGTCommand) throws {
        guard fileDescriptor >= 0 else {
            Self.logger?.error("Serial send refused, port not open: command=\(command.rawValue, privacy: .public)")
            throw PortError.notOpen
        }
        var byte = command.rawValue
        let written = withUnsafePointer(to: &byte) {
            Darwin.write(fileDescriptor, $0, 1)
        }
        guard written == 1 else {
            let err = errno
            Self.logger?.error("Serial write failed: command=\(command.rawValue, privacy: .public) errno=\(err, privacy: .public)")
            throw PortError.writeFailed(errno: err)
        }
        Self.logger?.debug("Sent command 0x\(String(command.rawValue, radix: 16), privacy: .public)")
    }
    
    // MARK: Inbound
    
    /// Framer + decoder over received bytes; runs only on `readLoopTask`, in order (F2).
    private func ingest(_ data: Data) {
        Self.logger?.debug("Received \(data.count) \(data.count == 1 ? "byte" : "bytes"): \(data)")
        for frame in framer.ingest(data) {
            guard let event = DGTDecoder.decode(frame) else {
                Self.logger?.debug(
                    "Undecoded frame: msg=0x\(String(frame.message, radix: 16), privacy: .public) len=\(frame.data.count)"
                )
                continue
            }
            eventContinuation?.yield(event)
        }
    }
    
    // MARK: termios Configuration
    
    /// 9600 8N1 raw, no flow control; clears the non-blocking flag used during `open`.
    private func configure(_ fd: Int32) throws {
        var settings = termios()
        guard tcgetattr(fd, &settings) == 0 else {
            throw PortError.configureFailed(errno: errno)
        }
        
        cfmakeraw(&settings)                       // raw: no canonical, echo, signals
        cfsetispeed(&settings, speed_t(B9600))
        cfsetospeed(&settings, speed_t(B9600))
        
        settings.c_cflag |= tcflag_t(CLOCAL | CREAD)   // ignore modem ctrl, enable receiver
        settings.c_cflag &= ~tcflag_t(PARENB)          // no parity      ┐
        settings.c_cflag &= ~tcflag_t(CSTOPB)          // 1 stop bit     ├ 8N1
        settings.c_cflag &= ~tcflag_t(CSIZE)           //                │
        settings.c_cflag |= tcflag_t(CS8)              // 8 data bits    ┘
        settings.c_cflag &= ~tcflag_t(CRTSCTS)         // no hardware flow control
        
        guard tcsetattr(fd, TCSANOW, &settings) == 0 else {
            throw PortError.configureFailed(errno: errno)
        }
        
        // Drop O_NONBLOCK so the readability source behaves like a pipe.
        let flags = fcntl(fd, F_GETFL)
        if flags != -1 {
            _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        }
    }
}
