import XCTest
@testable import Wrangler

final class ReportGeneratorTests: XCTestCase {
    func testMarkdownReportContainsHeaders() {
        let report = SyncReport(
            timestamp: .now,
            sourceRoot: URL(fileURLWithPath: "/src"),
            destinationRoot: URL(fileURLWithPath: "/dst"),
            duration: 60,
            averageThroughput: 1024 * 1024 * 50,
            filesCopied: [],
            filesUpdated: [],
            filesSkipped: [],
            filesDeleted: [],
            errors: [],
            totalBytesTransferred: 0,
            allVerified: true
        )

        let md = ReportGenerator.generateMarkdownReport(from: report)
        XCTAssertTrue(md.contains("# Wrangler Sync Report"))
        XCTAssertTrue(md.contains("**Source**"))
        XCTAssertTrue(md.contains("/src"))
    }
}
