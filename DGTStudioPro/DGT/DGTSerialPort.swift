//
//  DGTSerialPort.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import Foundation
import os

/// Owns the raw serial file descriptor for a connected DGT board and turns the
/// inbound byte stream into a stream of decoded `DGTEvent`s.
///
/// This is the serial-transport analogue of `StockfishEngine`: an `actor` that
/// confines all mutable I/O state, bounces inbound bytes in via a
/// `FileHandle.readabilityHandler` (exactly as the engine does for stdout), and
/// exposes results as an `AsyncStream`. The crucial discipline is that raw
/// bytes never escape this actor un-decoded — they pass through the pure,
/// fully-tested `DGTFramer` (framing) and `DGTDecoder` (semantics) here, so the
/// `@MainActor` connection only ever sees well-formed `DGTEvent`s.
///
/// Port configuration is raw Darwin `termios`: **9600 baud, 8N1, raw mode, no
/// flow control** — the parameters confirmed for the piece-detecting DGT
/// e-Board. The callout (`/dev/cu.*`) node is opened with `O_NONBLOCK` so the
/// `open` call itself can't hang on modem-control lines; the flag is cleared
/// immediately afterwards so the readability source behaves like a pipe.
internal actor DGTSerialPort {

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

    internal init() {}

    internal var isOpen: Bool { fileDescriptor >= 0 }

    // MARK: Open / Close

    /// Opens and configures the serial device at `path`, starts the read loop,
    /// and returns a stream of decoded events. The stream finishes when the
    /// port is closed (explicitly, or because the device went away).
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

        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        handle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return } // EOF / device removed
            Task { [weak self] in
                await self?.ingest(data)
            }
        }
        fileHandle = handle

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

        eventContinuation?.finish()
        eventContinuation = nil
        framer = DGTFramer()
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
    /// resulting events. Called on the actor from the readability handler's
    /// hop-in `Task`.
    private func ingest(_ data: Data) {
        Self.logger.debug("recv \(data.count) byte(s)")
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

        // Drop O_NONBLOCK so the readability source + availableData behaves like
        // a pipe (the handler only fires when bytes are actually ready).
        let flags = fcntl(fd, F_GETFL)
        if flags != -1 {
            _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
        }
    }
}
