
/// A discovered serial device. `path` is the BSD **callout** node (`cu.*`), not dial-in (`tty.*`):
/// dial-in blocks on carrier-detect the board doesn't drive - it would hang.
struct DGTSerialDevice: Identifiable, Equatable, Sendable {
    /// The `/dev/cu.*` callout path - also the stable identity, and since the one-board decree the
    /// *only* connect criterion: a device is the board iff this equals `DGTConnection.onlyBoardPath`.
    let path: String
    /// IORegistry `kIOTTYDeviceKey`, which `DGTDeviceDiscovery` also matches on - so today this is
    /// always `usbmodem01`. Display only: the connect panel and the session log name the board with
    /// it, and nothing anywhere decides anything from it.
    let name: String
    
    var id: String { path }
}
