import Foundation

struct SyncReport: Sendable {
    let timestamp: Date
    let sourceRoot: URL
    let destinationRoot: URL
    let duration: TimeInterval
    let averageThroughput: Double
    let filesCopied: [SyncedFileRecord]
    let filesUpdated: [SyncedFileRecord]
    let filesSkipped: [SyncedFileRecord]
    let filesDeleted: [SyncedFileRecord]
    let errors: [CopyError]
    let totalBytesTransferred: Int64
    let allVerified: Bool
}

struct SyncedFileRecord: Identifiable, Sendable {
    let id = UUID()
    let relativePath: String
    let fileSize: Int64
    let modificationDate: Date
    let ownerName: String?
    let action: SyncAction
    let checksum: String?
}

enum SyncAction: String, Sendable {
    case copied
    case replaced
    case deleted
    case skipped
    case failed
}
