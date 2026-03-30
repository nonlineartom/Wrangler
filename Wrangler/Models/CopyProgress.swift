import Foundation

struct CopyProgress: Sendable {
    let totalFiles: Int
    let completedFiles: Int
    let totalBytes: Int64
    let transferredBytes: Int64
    let currentFileName: String
    let currentFileSize: Int64
    let currentFileBytesTransferred: Int64
    let currentFileBlocksTotal: Int
    let currentFileBlocksCompleted: Int
    let startTime: Date
    let errors: [CopyError]
    let completedFileNames: [CompletedFile]

    var overallProgress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    var currentFileProgress: Double {
        guard currentFileSize > 0 else { return 0 }
        return Double(currentFileBytesTransferred) / Double(currentFileSize)
    }

    var elapsedTime: TimeInterval {
        Date.now.timeIntervalSince(startTime)
    }

    var throughputBytesPerSecond: Double {
        let elapsed = elapsedTime
        guard elapsed > 0 else { return 0 }
        return Double(transferredBytes) / elapsed
    }

    var estimatedTimeRemaining: TimeInterval? {
        let throughput = throughputBytesPerSecond
        guard throughput > 0 else { return nil }
        let remaining = Double(totalBytes - transferredBytes)
        return remaining / throughput
    }

    static var idle: CopyProgress {
        CopyProgress(
            totalFiles: 0,
            completedFiles: 0,
            totalBytes: 0,
            transferredBytes: 0,
            currentFileName: "",
            currentFileSize: 0,
            currentFileBytesTransferred: 0,
            currentFileBlocksTotal: 0,
            currentFileBlocksCompleted: 0,
            startTime: .now,
            errors: [],
            completedFileNames: []
        )
    }
}

struct CompletedFile: Identifiable, Sendable {
    let id = UUID()
    let relativePath: String
    let fileSize: Int64
    let checksum: String
    let verified: Bool
}

enum BlockState: Sendable {
    case pending
    case transferring
    case completed
    case failed
}
