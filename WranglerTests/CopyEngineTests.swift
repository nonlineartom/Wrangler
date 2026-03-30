import XCTest
@testable import Wrangler

final class CopyEngineTests: XCTestCase {
    func testByteCountFormatting() {
        XCTAssertEqual(ByteCountFormatting.throughputString(bytesPerSecond: 1024 * 1024 * 150), "150.0 MB/s")
        XCTAssertEqual(ByteCountFormatting.throughputString(bytesPerSecond: 1024 * 1024 * 1500), "1.5 GB/s")
        XCTAssertEqual(ByteCountFormatting.durationString(from: 65), "1m 05s")
        XCTAssertEqual(ByteCountFormatting.durationString(from: 3661), "1h 01m 01s")
    }

    func testReportGeneration() {
        let report = SyncReport(
            timestamp: Date(timeIntervalSince1970: 0),
            sourceRoot: URL(fileURLWithPath: "/Volumes/SSD/Project"),
            destinationRoot: URL(fileURLWithPath: "/Volumes/Server/Backup"),
            duration: 120,
            averageThroughput: 1024 * 1024 * 100,
            filesCopied: [
                SyncedFileRecord(
                    relativePath: "test.mxf",
                    fileSize: 1024 * 1024 * 100,
                    modificationDate: Date(timeIntervalSince1970: 0),
                    ownerName: "tom",
                    action: .copied,
                    checksum: "abc123"
                )
            ],
            filesUpdated: [],
            filesSkipped: [],
            filesDeleted: [],
            errors: [],
            totalBytesTransferred: 1024 * 1024 * 100,
            allVerified: true
        )

        let text = ReportGenerator.generateTextReport(from: report)
        XCTAssertTrue(text.contains("Wrangler Sync Report"))
        XCTAssertTrue(text.contains("test.mxf"))
        XCTAssertTrue(text.contains("All checksums match"))
    }
}
