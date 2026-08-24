import Foundation
import IOKit
import IOKit.serial
import os

/// Enumerates the board's serial device and **only** it: the match pins `kIOTTYDeviceKey` to the
/// TTY name derived from `onlyBoardPath`, so a stranger is invisible rather than filtered out
/// afterwards.
///
/// None of this runs under ⌘U. The one production caller is `DGTConnection.enumerateDevices`, a
/// seam tests replace (F9), so hardware is the only witness.
enum DGTDeviceDiscovery {
    
    private static let logger = AppLog.logger(.dgt)
    
    /// The board, or nothing. At most one service can carry the pinned TTY name, so the result is
    /// 0 or 1 - which is why `DGTAutoConnectPolicy` takes the `first` match with no tiebreak.
    /// Unsorted: enumeration order is not an opinion about order.
    static func availableDevices() -> [DGTSerialDevice] {
        guard let matching = IOServiceMatching(kIOSerialBSDServiceValue) else {
            logger?.error("IOServiceMatching returned nil for serial services")
            return []
        }
        
        // All serial BSD types, exactly one TTY: the matching carries the decree; the node name is
        // derived from the path constant, never spelled twice.
        (matching as NSMutableDictionary)[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
        let calloutPrefix = "/dev/cu."
        if DGTConnection.onlyBoardPath.hasPrefix(calloutPrefix) {
            (matching as NSMutableDictionary)[kIOTTYDeviceKey] =
            String(DGTConnection.onlyBoardPath.dropFirst(calloutPrefix.count))
        } else {
            // Unreachable today: `onlyBoardPath` is a literal `/dev/cu.` path, so this is a
            // tripwire for a future edit to that one constant, not a runtime branch. Matching wide
            // keeps the membership checks correct while this line names the surprise.
            logger?.error("Configured board path is not a /dev/cu. path; matching all serial devices")
        }
        
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            logger?.error("IOServiceGetMatchingServices failed: \(result, privacy: .public)")
            return []
        }
        defer { IOObjectRelease(iterator) }
        
        var devices: [DGTSerialDevice] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let path = stringProperty(service, kIOCalloutDeviceKey) {
                // This reads back the very property the match pinned, so `name` is that TTY name
                // every time; `?? path` needs a service that matched on a key it then failed to report.
                let name = stringProperty(service, kIOTTYDeviceKey) ?? path
                devices.append(DGTSerialDevice(path: path, name: name))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        
        // Debug, not info: fires on every launch, Rescan and reconnect lap - present/absent is the
        // one fact callers ask about.
        logger?.debug("Board node \(devices.isEmpty ? "absent" : "present", privacy: .public)")
        return devices
    }
    
    /// `takeRetainedValue` because `IORegistryEntryCreateCFProperty` follows the Create rule.
    private static func stringProperty(_ service: io_object_t, _ key: String) -> String? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        ) else { return nil }
        return cf.takeRetainedValue() as? String
    }
}
