import XCTest
@testable import Wrangler

final class DiffEngineTests: XCTestCase {
    func testFileEntryMediaDetection() {
        let mxf = FileEntry(relativePath: "test.mxf", fileName: "test.mxf", isDirectory: false, fileSize: 100, modificationDate: .now)
        XCTAssertTrue(mxf.isVideoFile)
        XCTAssertTrue(mxf.isMediaFile)
        XCTAssertFalse(mxf.isImageFile)

        let jpg = FileEntry(relativePath: "test.jpg", fileName: "test.jpg", isDirectory: false, fileSize: 100, modificationDate: .now)
        XCTAssertFalse(jpg.isVideoFile)
        XCTAssertTrue(jpg.isImageFile)
        XCTAssertTrue(jpg.isMediaFile)

        let txt = FileEntry(relativePath: "test.txt", fileName: "test.txt", isDirectory: false, fileSize: 100, modificationDate: .now)
        XCTAssertFalse(txt.isMediaFile)
    }

    func testDiffStatusColors() {
        XCTAssertEqual(DiffStatus.identical.label, "Identical")
        XCTAssertEqual(DiffStatus.newOnSource.label, "New")
        XCTAssertEqual(DiffStatus.modified.label, "Modified")
        XCTAssertEqual(DiffStatus.orphaned.label, "Orphaned")
    }

    func testDiffSummaryEmpty() {
        let summary = DiffSummary.empty
        XCTAssertEqual(summary.totalFiles, 0)
        XCTAssertEqual(summary.bytesToTransfer, 0)
    }
}
