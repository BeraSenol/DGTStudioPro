
/// A discovered serial device. `path` is the BSD **callout** node (`cu.*`), not dial-in
/// (`tty.*`): dial-in blocks on carrier-detect the board doesn't drive — it would hang.
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
