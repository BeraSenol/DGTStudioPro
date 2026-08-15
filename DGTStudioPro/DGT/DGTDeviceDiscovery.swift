import Foundation
import IOKit
import IOKit.serial
import os

/// Enumerates the board's serial device — and *only* it: `kIOTTYDeviceKey` is pinned to the
/// board's TTY name (derived from `onlyBoardPath`), so the app cannot see a device it would
/// never connect to. The decree is a fact about the query, not a filter after it.
enum DGTDeviceDiscovery {
    
    private static let logger = AppLog.logger(.dgt)
    
    /// Every matching callout device, unsorted — enumeration order is not an opinion about order.
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
            // A non-callout constant would be a programmer error at one symbol; matching wide keeps the
            // membership checks correct while this line names the surprise.
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
                let name = stringProperty(service, kIOTTYDeviceKey) ?? path
                devices.append(DGTSerialDevice(path: path, name: name))
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        
        // Debug, not info: fires on every launch, Rescan and reconnect lap — present/absent is the one
        // fact callers ask about.
        logger?.debug("Board node \(devices.isEmpty ? "absent" : "present", privacy: .public)")
        return devices
    }
    
    /// Reads a string-valued IORegistry property for a service, or nil.
    private static func stringProperty(_ service: io_object_t, _ key: String) -> String? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        ) else { return nil }
        return cf.takeRetainedValue() as? String
    }
}
