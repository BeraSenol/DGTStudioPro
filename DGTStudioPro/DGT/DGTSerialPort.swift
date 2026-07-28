//
//  DGTSerialPort.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import Foundation
import os

/// The transport seam `DGTConnection` drives (F9). `DGTSerialPort` below is
/// the real implementation over a `/dev/cu.*` file descriptor; tests inject a
/// scripted fake so connect, event routing, stream-end, and reconnect logic
/// run hermetically, without hardware.
///
/// One contract matters to callers and fakes alike: **the returned event
/// stream finishing is the single "port is gone" signal.** A deliberate
/// `close()` and a vanished device both end in the stream finishing;
/// `DGTConnection` tells the two apart by whether its read task was cancelled
/// (teardown cancels it, an unplug does not).
internal protocol DGTPortProviding: Actor {
    /// Opens the device and returns the decoded event stream. The stream
    /// finishes when the port closes — explicitly via `close()`, or because
    /// the device went away and the port closed itself (F1).
    func open(path: String) throws -> AsyncStream<DGTEvent>
    /// Closes the port and finishes the event stream. No-op when not open.
    func close()
    /// Sends a single-byte command to the board.
    func send(_ command: DGTCommand) throws
}

/// Owns the raw serial file descriptor for a connected DGT board and turns the
/// inbound byte stream into a stream of decoded `DGTEvent`s.
///
/// This is the serial-transport analogue of `StockfishEngine`: an `actor` that
/// confines all mutable I/O state and exposes results as an `AsyncStream`. The
/// crucial discipline is that raw bytes never escape this actor un-decoded —
/// they pass through the pure, fully-tested `DGTFramer` (framing) and
/// `DGTDecoder` (semantics) here, so the `@MainActor` connection only ever
/// sees well-formed `DGTEvent`s.
///
/// ## Inbound pipeline (F2)
///
/// The readability handler runs on a *serial* dispatch queue and `yield`s each
/// chunk into an `AsyncStream<Data>`; consecutive yields from one thread reach
/// the stream in call order, and a single long-lived actor task consumes it —
/// so chunk order is preserved end to end. (The previous design spawned one
/// unstructured `Task` per chunk to hop onto the actor; separate unstructured
/// tasks carry no ordering guarantee, and two swapped chunks would corrupt the
/// framer's state machine mid-frame — a desync indistinguishable from flaky
/// hardware.)
///
/// ## Device removal (F1)
///
/// The handler reads with raw `read(2)` rather than `availableData`: on a dead
/// descriptor — the USB adapter unplugged mid-session — `availableData` can
/// raise an Objective-C exception, which inside a GCD callback is a crash.
/// `read` just returns 0 (EOF) or -1 (`ENXIO`/`EIO`), which the handler turns
/// into the one signal that matters: it removes itself and finishes the byte
/// stream, the read loop ends, and the port closes itself — finishing the
/// *event* stream that `DGTConnection.handleStreamEnd()` keys on to route
/// between the failure banner and the M7.3 reconnect loop. (The previous
/// design returned on empty data without finishing anything: the event stream
/// never ended, `handleStreamEnd()` never ran, auto-reconnect was unreachable
/// from a real unplug — and the level-triggered read source kept re-firing at
/// EOF, busy-spinning its queue.)
///
/// Port configuration is raw Darwin `termios`: **9600 baud, 8N1, raw mode, no
/// flow control** — the parameters confirmed for the piece-detecting DGT
/// e-Board. The callout (`/dev/cu.*`) node is opened with `O_NONBLOCK` so the
/// `open` call itself can't hang on modem-control lines; the flag is cleared
/// immediately afterwards so the readability source behaves like a pipe.
internal actor DGTSerialPort: DGTPortProviding {
    
    // MARK: Logging
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "dgt"
    )
    
    // MARK: Errors
    
    internal enum PortError: Error, Equatable {
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
    
    /// Feeds raw chunks from the readability handler to `readLoopTask`, in
    /// arrival order (F2). Finished by the handler on EOF/read-error (F1)
    /// or by `close()`.
    private var byteContinuation: AsyncStream<Data>.Continuation?
    
    /// The single actor-isolated consumer of the byte stream. Ends when the
    /// byte stream finishes; `readSourceEnded()` then decides whether that
    /// end was deliberate.
    private var readLoopTask: Task<Void, Never>?
    
    internal init() {}
    
    internal var isOpen: Bool { fileDescriptor >= 0 }
    
    // MARK: Open / Close
    
    /// Opens and configures the serial device at `path`, starts the ordered
    /// inbound pipeline, and returns a stream of decoded events. The stream
    /// finishes when the port closes — explicitly, or because the device
    /// went away (F1).
    internal func open(path: String) throws -> AsyncStream<DGTEvent> {
        guard fileDescriptor < 0 else {
            Self.logger.error("open() called while already open")
            throw PortError.alreadyOpen
        }
        
        let fd = path.withCString { Darwin.open($0, O_RDWR | O_NOCTTY | O_NONBLOCK) }
        guard fd >= 0 else {
            let err = errno
            Self.logger.error("open(\(path, privacy: .public)) failed: errno=\(err, privacy: .public)")
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
        // Raw `read(2)` instead of `availableData` (F1) — see the type doc.
        // The closure captures no `self`: it only bridges bytes (and the
        // end-of-source signal) into the stream.
        handle.readabilityHandler = { handle in
            var buffer = [UInt8](repeating: 0, count: 512)
            let count = Darwin.read(handle.fileDescriptor, &buffer, buffer.count)
            if count > 0 {
                byteContinuation.yield(Data(buffer[0..<count]))
            } else if count == 0 {
                // EOF — the device is gone. Stop the source, end the pipeline.
                handle.readabilityHandler = nil
                byteContinuation.finish()
            } else if errno == EAGAIN || errno == EINTR {
                // Spurious wakeup — the next readability callback retries.
            } else {
                // Fatal read error (ENXIO / EIO after an unplug). Same exit.
                handle.readabilityHandler = nil
                byteContinuation.finish()
            }
        }
        fileHandle = handle
        
        // One long-lived, actor-isolated consumer: `ingest` runs here, on
        // the actor, in stream order. (An unstructured `Task` created in an
        // actor-isolated method inherits the actor's isolation.)
        // Load-bearing ordering: this task is created before `eventContinuation`
        // is assigned (by the `AsyncStream` build closure below), and is safe
        // only because a `Task` created in actor-isolated code cannot run until
        // this synchronous stretch yields the actor. Introducing any `await`
        // between here and the `return` lets `ingest` run first, and
        // `eventContinuation?.yield(event)` would drop those events silently.
        readLoopTask = Task {
            for await chunk in bytes {
                ingest(chunk)
            }
            readSourceEnded()
        }
        
        Self.logger.info("Opened serial port \(path, privacy: .public) (fd=\(fd))")
        
        return AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }
    
    /// Closes the port, finishes the event stream, and resets all state. Safe
    /// to call when not open (no-op).
    internal func close() {
        guard fileDescriptor >= 0 else { return }
        Self.logger.info("Closing serial port (fd=\(self.fileDescriptor))")
        
        fileHandle?.readabilityHandler = nil
        fileHandle = nil
        Darwin.close(fileDescriptor)
        fileDescriptor = -1
        
        // End the byte pipeline; `readLoopTask` drains what's buffered and
        // exits on its own (`readSourceEnded()` sees fd == -1 and stands
        // down — late frames yield into a finished event stream, harmlessly).
        byteContinuation?.finish()
        byteContinuation = nil
        readLoopTask = nil
        
        eventContinuation?.finish()
        eventContinuation = nil
        framer = DGTFramer()
    }
    
    /// Runs when the byte stream finishes. If `close()` initiated it, the fd
    /// is already -1 and everything is torn down — nothing to do. Otherwise
    /// the device vanished or the read failed (F1): close the port ourselves,
    /// which finishes the *event* stream — the signal `DGTConnection` keys on.
    private func readSourceEnded() {
        guard fileDescriptor >= 0 else { return }
        Self.logger.error("Serial read source ended (device vanished or read failed) — closing port")
        close()
    }
    
    // MARK: Write
    
    /// Sends a single-byte command to the board.
    internal func send(_ command: DGTCommand) throws {
        guard fileDescriptor >= 0 else {
            Self.logger.error("send(\(command.rawValue, privacy: .public)) while not open")
            throw PortError.notOpen
        }
        var byte = command.rawValue
        let written = withUnsafePointer(to: &byte) {
            Darwin.write(fileDescriptor, $0, 1)
        }
        guard written == 1 else {
            let err = errno
            Self.logger.error("write of command \(command.rawValue, privacy: .public) failed: errno=\(err, privacy: .public)")
            throw PortError.writeFailed(errno: err)
        }
        Self.logger.debug("send command 0x\(String(command.rawValue, radix: 16), privacy: .public)")
    }
    
    // MARK: Inbound
    
    /// Feeds received bytes through the framer + decoder and yields any
    /// resulting events. Runs only on `readLoopTask`, in chunk-arrival
    /// order (F2).
    private func ingest(_ data: Data) {
        Self.logger.debug("Received \(data.count) \(data.count == 1 ? "byte" : "bytes"): \(data)")
        for frame in framer.ingest(data) {
            guard let event = DGTDecoder.decode(frame) else {
                Self.logger.debug(
                    "undecoded frame: msg=0x\(String(frame.message, radix: 16), privacy: .public) len=\(frame.data.count)"
                )
                continue
            }
            eventContinuation?.yield(event)
        }
    }
    
    // MARK: termios Configuration
    
    /// Configures the fd for 9600 8N1 raw, no flow control, then clears the
    /// non-blocking flag used during `open`.
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
        
        // Drop O_NONBLOCK so the readability source behaves like a pipe (the
        // handler only fires when bytes are actually ready).
        let flags = fcntl(fd, F_GETFL)
        if flags != -1 {
            _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        }
    }
}
