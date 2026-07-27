//
//  DGTSerialDevice.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

/// A serial device discovered on the system that the app could connect to.
///
/// `path` is the BSD callout device (`/dev/cu.*`) opened by `DGTSerialPort`.
/// We deliberately use the *callout* (`cu.`) node, not the *dial-in* (`tty.`)
/// node: opening a `tty.` device blocks until carrier/DCD is asserted, which a
/// DGT board does not drive, so it would hang. `cu.` opens immediately.
///
/// `isLikelyBoard` is a soft heuristic for ordering the connect dialog — the
/// user always confirms the final choice, so a wrong guess is harmless.
internal struct DGTSerialDevice: Identifiable, Equatable, Sendable {
    /// The `/dev/cu.*` callout path — also serves as the stable identity.
    internal let path: String
    /// Human-readable name from the IORegistry (`kIOTTYDeviceKey`), e.g.
    /// `usbserial-FTXYZ`. Falls back to the path when unavailable.
    internal let name: String
    
    internal var id: String { path }
    
    /// Whether this device looks like a USB serial adapter of the kind a DGT
    /// board presents as. Used only to sort candidates; never to auto-connect.
    internal static let boardNameHints = ["usbserial", "usbmodem", "ftdi", "dgt"]
    
    internal var isLikelyBoard: Bool {
        let haystack = (path + " " + name).lowercased()
        return Self.boardNameHints.contains { haystack.contains($0) }
    }
}
