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
/// from the IORegistry, and hands back value-type `DGTSerialDevice`s. The
/// connect dialog presents these (likely-board candidates first) and the user
/// confirms one before `DGTSerialPort` opens it.
///
/// Pure enumeration — no device is opened here. Under the App Sandbox this
/// still requires the serial entitlement to return results (see the D2
/// entitlements note).
internal enum DGTDeviceDiscovery {
    
    private static let logger = Logger(
        subsystem: "com.berasenol.dgtstudiopro",
        category: "dgt"
    )
    
    /// Returns all serial callout devices, with likely-board candidates first.
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
        
        logger.info("Discovered \(devices.count) serial device(s)")
        
        // Stable order: likely boards first, then alphabetical by path.
        return devices.sorted {
            $0.isLikelyBoard != $1.isLikelyBoard
            ? $0.isLikelyBoard && !$1.isLikelyBoard
            : $0.path < $1.path
        }
    }
    
    /// Reads a string-valued IORegistry property for a service, or nil.
    private static func stringProperty(_ service: io_object_t, _ key: String) -> String? {
        guard let cf = IORegistryEntryCreateCFProperty(
            service, key as CFString, kCFAllocatorDefault, 0
        ) else { return nil }
        return cf.takeRetainedValue() as? String
    }
}
