import Foundation

enum ByteCountFormatting {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    static func string(fromByteCount bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }

    static func throughputString(bytesPerSecond: Double) -> String {
        let mbps = bytesPerSecond / (1024 * 1024)
        if mbps >= 1000 {
            return String(format: "%.1f GB/s", mbps / 1024)
        } else if mbps >= 1 {
            return String(format: "%.1f MB/s", mbps)
        } else {
            let kbps = bytesPerSecond / 1024
            return String(format: "%.0f KB/s", kbps)
        }
    }

    static func durationString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
