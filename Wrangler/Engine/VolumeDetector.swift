import Foundation
import AppKit

struct VolumeInfo: Identifiable, Sendable {
    let id: String
    let url: URL
    let name: String
    let totalCapacity: Int64
    let availableCapacity: Int64
    let isRemovable: Bool
    let isNetwork: Bool
    let isLocal: Bool

    var usedCapacity: Int64 { totalCapacity - availableCapacity }
    var usagePercent: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity)
    }

    var typeLabel: String {
        if isNetwork { return "Network" }
        if isRemovable { return "External" }
        return "Local"
    }

    var typeIcon: String {
        if isNetwork { return "server.rack" }
        if isRemovable { return "externaldrive.fill" }
        return "internaldrive.fill"
    }
}

enum VolumeDetector {
    static func mountedVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsRemovableKey,
            .volumeIsLocalKey,
            .volumeIsInternalKey
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }

            let name = values.volumeName ?? url.lastPathComponent
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let isRemovable = values.volumeIsRemovable ?? false
            let isLocal = values.volumeIsLocal ?? true
            let isInternal = values.volumeIsInternal ?? true

            return VolumeInfo(
                id: url.path,
                url: url,
                name: name,
                totalCapacity: total,
                availableCapacity: available,
                isRemovable: isRemovable,
                isNetwork: !isLocal,
                isLocal: isLocal && isInternal
            )
        }
    }

    static func volumeInfo(for url: URL) -> VolumeInfo? {
        let volumes = mountedVolumes()
        return volumes.first { url.path.hasPrefix($0.url.path) }
    }

    static func volumeIcon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}
