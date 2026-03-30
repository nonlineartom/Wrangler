import Foundation
import IOKit
import DiskArbitration
import SwiftUI

// MARK: - Drive Transport

enum DriveTransport: Sendable, Equatable {
    case usbLow       // USB 1.0 Low Speed  — 1.5 Mbps
    case usbFull      // USB 1.1 Full Speed — 12 Mbps
    case usb2         // USB 2.0 High Speed — 480 Mbps  ← common bad-cable result
    case usb3         // USB 3.0 / 3.1 Gen 1 — 5 Gbps
    case usb31        // USB 3.1 Gen 2       — 10 Gbps
    case usb32        // USB 3.2 Gen 2×2     — 20 Gbps
    case thunderbolt  // Thunderbolt 3/4/5   — 40–120 Gbps
    case networkShare
    case internalDisk
    case unknown

    var label: String {
        switch self {
        case .usbLow:       return "USB 1.0 (1.5 Mb/s)"
        case .usbFull:      return "USB 1.1 (12 Mb/s)"
        case .usb2:         return "USB 2.0 (480 Mb/s)"
        case .usb3:         return "USB 3.0 (5 Gb/s)"
        case .usb31:        return "USB 3.1 Gen 2 (10 Gb/s)"
        case .usb32:        return "USB 3.2 Gen 2×2 (20 Gb/s)"
        case .thunderbolt:  return "Thunderbolt"
        case .networkShare: return "Network"
        case .internalDisk: return "Internal"
        case .unknown:      return "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .usbLow:       return "USB 1.0"
        case .usbFull:      return "USB 1.1"
        case .usb2:         return "USB 2.0"
        case .usb3:         return "USB 3.0"
        case .usb31:        return "USB 3.1"
        case .usb32:        return "USB 3.2"
        case .thunderbolt:  return "Thunderbolt"
        case .networkShare: return "Network"
        case .internalDisk: return "Internal"
        case .unknown:      return "Unknown"
        }
    }

    /// Practical throughput ceiling (bytes/sec) for this connection.
    /// Based on real-world overhead, not raw line rate.
    var throughputCeiling: Int64 {
        switch self {
        case .usbLow:       return 150_000
        case .usbFull:      return 1_200_000
        case .usb2:         return 50_000_000       // ~50 MB/s
        case .usb3:         return 450_000_000      // ~450 MB/s
        case .usb31:        return 1_000_000_000    // ~1 GB/s
        case .usb32:        return 2_000_000_000    // ~2 GB/s
        case .thunderbolt:  return 3_800_000_000    // ~3.8 GB/s (TB3/4)
        case .internalDisk: return 7_000_000_000
        case .networkShare, .unknown: return 0
        }
    }

    /// True when the connection speed is likely throttling a modern external SSD.
    var isBottleneckForSSD: Bool {
        self == .usb2 || self == .usbFull || self == .usbLow
    }

    var sfSymbol: String {
        switch self {
        case .thunderbolt:  return "bolt.fill"
        case .networkShare: return "network"
        case .internalDisk: return "internaldrive"
        case .usbLow, .usbFull, .usb2: return "exclamationmark.triangle.fill"
        default:            return "cable.connector.horizontal"
        }
    }

    var badgeColor: Color {
        if isBottleneckForSSD { return .orange }
        if self == .thunderbolt { return .blue }
        return .secondary
    }
}

// MARK: - Connection Info

struct DriveConnectionInfo: Sendable {
    let transport: DriveTransport

    var warningMessage: String? {
        switch transport {
        case .usbLow, .usbFull:
            return "Connected at USB 1.x speeds — this cable is not suitable for SSDs"
        case .usb2:
            return "Connected at USB 2.0 — transfer speed is severely limited. Try a different cable or port."
        default:
            return nil
        }
    }
}

// MARK: - Detector

enum DriveConnectionDetector {

    /// Returns the connection info for the volume that contains `url`.
    /// Fast synchronous call — safe to run on the main thread.
    static func detect(for url: URL) -> DriveConnectionInfo {
        // Network volumes
        if let vals = try? url.resourceValues(forKeys: [.volumeIsLocalKey]),
           vals.volumeIsLocal == false {
            return DriveConnectionInfo(transport: .networkShare)
        }

        // Internal
        if let vals = try? url.resourceValues(forKeys: [.volumeIsInternalKey]),
           vals.volumeIsInternal == true {
            return DriveConnectionInfo(transport: .internalDisk)
        }

        // External — look up via IOKit
        guard let bsdName = wholeDiskBSDName(for: url) else {
            return DriveConnectionInfo(transport: .unknown)
        }

        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOBSDNameMatching(kIOMainPortDefault, 0, bsdName)
        )
        guard service != 0 else { return DriveConnectionInfo(transport: .unknown) }
        defer { IOObjectRelease(service) }

        // Thunderbolt takes priority (TB ports can also enumerate as USB)
        if ancestorIsThunderbolt(service) {
            return DriveConnectionInfo(transport: .thunderbolt)
        }

        // USB — read the "Device Speed" property from nearest USB host ancestor
        if let transport = usbTransport(from: service) {
            return DriveConnectionInfo(transport: transport)
        }

        return DriveConnectionInfo(transport: .unknown)
    }

    // MARK: - Private helpers

    /// Get the whole-disk BSD name (e.g. "disk2") for the volume at `url`.
    private static func wholeDiskBSDName(for url: URL) -> String? {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return nil }
        guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session,
                                                    url as CFURL) else { return nil }
        // Prefer the whole-disk object so IOBSDNameMatching finds the device node
        let target = DADiskCopyWholeDisk(disk) ?? disk
        guard let bsdPtr = DADiskGetBSDName(target) else { return nil }
        return String(cString: bsdPtr)
    }

    /// Walk parent chain (up to 20 levels) looking for a Thunderbolt class.
    private static func ancestorIsThunderbolt(_ service: io_service_t) -> Bool {
        var current: io_object_t = service
        IOObjectRetain(current)
        defer { IOObjectRelease(current) }

        for _ in 0..<20 {
            let name = ioClassName(current)
            if name.contains("Thunderbolt") || name.contains("thunderbolt") {
                return true
            }
            var parent: io_object_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS,
                  parent != 0 else { break }
            IOObjectRelease(current)
            current = parent
        }
        return false
    }

    /// Search ancestor chain for the USB "Device Speed" property.
    private static func usbTransport(from service: io_service_t) -> DriveTransport? {
        let result = IORegistryEntrySearchCFProperty(
            service,
            kIOServicePlane,
            "Device Speed" as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateParents | kIORegistryIterateRecursively)
        )
        guard let speed = result as? Int else { return nil }

        // Values from IOKit/usb/USBSpec.h:
        //   0 kUSBDeviceSpeedLow        1.5 Mbps
        //   1 kUSBDeviceSpeedFull       12  Mbps
        //   2 kUSBDeviceSpeedHigh       480 Mbps  (USB 2.0)
        //   3 kUSBDeviceSpeedSuper      5   Gbps  (USB 3.0)
        //   4 kUSBDeviceSpeedSuperPlus  10  Gbps  (USB 3.1 Gen 2)
        //   5 kUSBDeviceSpeedSuperPlusBy2  20 Gbps (USB 3.2 Gen 2×2)
        switch speed {
        case 0:  return .usbLow
        case 1:  return .usbFull
        case 2:  return .usb2
        case 3:  return .usb3
        case 4:  return .usb31
        case 5:  return .usb32
        default: return .usb3   // future SuperSpeed tier — assume at least Gen 1
        }
    }

    /// Read the IOKit class name for an object without dealing with io_name_t tuples.
    private static func ioClassName(_ obj: io_object_t) -> String {
        var buf = [CChar](repeating: 0, count: 128)
        IOObjectGetClass(obj, &buf)
        return String(cString: buf)
    }
}
