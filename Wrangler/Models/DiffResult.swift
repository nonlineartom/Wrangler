import Foundation

struct DiffResult: Sendable {
    let sourceRoot: URL
    let destinationRoot: URL
    let entries: [DiffEntry]
    let tree: [DiffEntry]
    let summary: DiffSummary
    let timestamp: Date

    static var empty: DiffResult {
        DiffResult(
            sourceRoot: URL(fileURLWithPath: "/"),
            destinationRoot: URL(fileURLWithPath: "/"),
            entries: [],
            tree: [],
            summary: .empty,
            timestamp: .now
        )
    }
}

struct DiffSummary: Sendable {
    let totalFiles: Int
    let identicalCount: Int
    let modifiedCount: Int
    let newOnSourceCount: Int
    let orphanedCount: Int
    let totalSourceSize: Int64
    let totalDestinationSize: Int64
    let bytesToTransfer: Int64

    static var empty: DiffSummary {
        DiffSummary(
            totalFiles: 0,
            identicalCount: 0,
            modifiedCount: 0,
            newOnSourceCount: 0,
            orphanedCount: 0,
            totalSourceSize: 0,
            totalDestinationSize: 0,
            bytesToTransfer: 0
        )
    }
}
