//
//  DGTDeviceDiscovery.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 25/05/2026.
//

import Foundation
import IOKit
import IOKit.serial
import os

/// Enumerates the board's serial device via IOKit — and *only* the board's.
///
/// This is the "device discovery" half of D2. Since the one-board decree
/// (2 Aug 2026) every consumer asks one membership question — is
/// `DGTConnection.onlyBoardPath` attached? — and since 4 Aug the **matching
/// dictionary itself carries the decree**: `kIOTTYDeviceKey` is pinned to
/// the board's TTY name, derived from the one path constant so the decree
/// keeps a single spelling. IOKit hands back that node or nothing; the
/// Bluetooth and debug consoles the app used to enumerate-and-ignore are no
/// longer even seen. "Never account for other devices" is a fact about the
/// query now, not a filter after it. Consumers unchanged: launch
/// auto-connect, the reconnect loop, and the connect window's not-found
/// panel.
///
/// Pure enumeration — no device is opened here. Under the App Sandbox this
/// still requires the serial entitlement to return results (see the D2
/// entitlements note).
internal enum DGTDeviceDiscovery {
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "dgt"
    )
    
    /// Returns every serial callout device attached right now, unsorted.
    ///
    /// Unsorted deliberately, as of 3 Aug 2026. This used to order
    /// likely-board candidates first, for a connect dialog that no longer
    /// exists; every caller since the one-board decree asks whether
    /// `DGTConnection.onlyBoardPath` is present, and a membership test has no
    /// opinion about order. The IORegistry order is whatever IOKit hands back
    /// — nothing renders it, so nothing can depend on it.
    internal static func availableDevices() -> [DGTSerialDevice] {
        guard let matching = IOServiceMatching(kIOSerialBSDServiceValue) else {
            logger.error("IOServiceMatching returned nil for serial services")
            return []
        }
        
        // All serial BSD types — but exactly one TTY (4 Aug 2026): the
        // matching carries the one-board decree. `kIOTTYDeviceKey` is the
        // node name after `cu.`/`tty.`, derived from the path constant
        // rather than spelled a second time.
        (matching as NSMutableDictionary)[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
        let calloutPrefix = "/dev/cu."
        if DGTConnection.onlyBoardPath.hasPrefix(calloutPrefix) {
            (matching as NSMutableDictionary)[kIOTTYDeviceKey] =
                String(DGTConnection.onlyBoardPath.dropFirst(calloutPrefix.count))
        } else {
            // A non-callout constant would be a programmer error at one
            // symbol; matching wide keeps the membership checks correct
            // while this line names the surprise.
            logger.error("onlyBoardPath is not a /dev/cu. path; matching all serial devices")
        }
        
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else {
            logger.error("IOServiceGetMatchingServices failed: \(result, privacy: .public)")
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
        
        // Debug, not info: this fires on every launch, every Rescan and
        // every reconnect lap. Since the matching narrowed to the board's
        // node it finally states the one fact callers ask about — but they
        // log their own answers with context, so this stays the quiet
        // transport echo. (It read "Enumerated 4 serial device(s)" for two
        // days, which is what prompted the narrowing: a count of ignored
        // devices is a line you learn to read past.)
        logger.debug("Board node \(devices.isEmpty ? "absent" : "present", privacy: .public)")
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
