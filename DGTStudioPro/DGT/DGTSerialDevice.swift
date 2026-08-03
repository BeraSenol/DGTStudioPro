//
//  DGTSerialDevice.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

// No `isLikelyBoard` / `boardNameHints` (deleted 3 Aug 2026). The heuristic
// scored a device on name fragments — "usbserial", "usbmodem", "ftdi", "dgt"
// — and existed to order the connect dialog's device list with the plausible
// candidates on top. The dialog died with the one-board decree (2 Aug 2026),
// and after it the only consumer left was `DGTDeviceDiscovery`'s sort, which
// ordered a list no surface renders: every remaining consumer asks "is
// `DGTConnection.onlyBoardPath` among these", and a membership test does not
// care what order it is asked in.
//
// This is D41′'s disposition rather than `DGTSerialPort.isOpen`'s: not a
// symbol waiting for a consumer, but one whose question a better sibling
// already answers exactly. A constant path is an exact match; a name
// heuristic is a guess at the same thing, and keeping a guess beside the
// answer is how a future reader ends up connecting to a stranger that
// happened to contain "dgt".
//
// The doc this replaces justified keeping it with "Diagnostics still
// enumerates strangers". Diagnostics does not, and never did — the claim was
// a named consumer that doesn't consume, which is the anti-pattern that keeps
// dead code alive by sounding like a reason. Re-adding this needs a reader
// first, and the reader would need to explain why an exact path is not enough.

/// A serial device discovered on the system that the app could connect to.
///
/// `path` is the BSD callout device (`/dev/cu.*`) opened by `DGTSerialPort`.
/// We deliberately use the *callout* (`cu.`) node, not the *dial-in* (`tty.`)
/// node: opening a `tty.` device blocks until carrier/DCD is asserted, which a
/// DGT board does not drive, so it would hang. `cu.` opens immediately.
internal struct DGTSerialDevice: Identifiable, Equatable, Sendable {
    /// The `/dev/cu.*` callout path — also serves as the stable identity, and
    /// since the one-board decree the *only* connect criterion: a device is
    /// the board iff this equals `DGTConnection.onlyBoardPath`.
    internal let path: String
    /// Human-readable name from the IORegistry (`kIOTTYDeviceKey`), e.g.
    /// `usbserial-FTXYZ`. Falls back to the path when unavailable. Display
    /// only — the connect panel and the session log name the board with it,
    /// and nothing ever decides anything from it.
    internal let name: String

    internal var id: String { path }
}
