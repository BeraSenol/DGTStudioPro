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

/// Enumerates the serial devices currently attached to the system via IOKit.
///
/// This is the "device discovery" half of D2. It matches all BSD serial
/// services (`IOSerialBSDClient`), reads each one's callout path and TTY name
/// from the IORegistry, and hands back value-type `DGTSerialDevice`s. Since
/// the one-board decree (2 Aug 2026) the only consumers are presence checks —
/// is `DGTConnection.onlyBoardPath` among these? — for launch auto-connect,
/// the reconnect loop, and the connect window's not-found panel.
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
        
        // Restrict to all serial BSD types (RS-232, modem, etc.).
        (matching as NSMutableDictionary)[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
        
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
        
        // Debug, not info: this fires on every launch, every Rescan and every
        // reconnect lap, and the count answers a question nobody asks — the
        // one that matters ("is the board there?") is logged by the callers
        // that can actually tell. A line that always appears and never
        // decides anything is a line you learn to read past.
        logger.debug("Enumerated \(devices.count) serial device(s)")
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
