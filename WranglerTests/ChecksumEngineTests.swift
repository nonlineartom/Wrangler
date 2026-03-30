import XCTest
@testable import Wrangler

final class ChecksumEngineTests: XCTestCase {
    func testChecksumConsistency() async throws {
        // Create a temp file with known content
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let testFile = tempDir.appendingPathComponent("test.bin")
        let testData = Data(repeating: 0xAB, count: 1024 * 1024) // 1MB
        try testData.write(to: testFile)

        let engine = ChecksumEngine()

        // Same file should produce same checksum
        let checksum1 = try await engine.computeChecksum(for: testFile)
        let checksum2 = try await engine.computeChecksum(for: testFile)

        XCTAssertEqual(checksum1, checksum2)
        XCTAssertEqual(checksum1.count, 64) // SHA256 = 64 hex chars
    }

    func testDifferentContentsDifferentChecksum() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("file1.bin")
        let file2 = tempDir.appendingPathComponent("file2.bin")
        try Data(repeating: 0xAA, count: 1024).write(to: file1)
        try Data(repeating: 0xBB, count: 1024).write(to: file2)

        let engine = ChecksumEngine()

        let checksum1 = try await engine.computeChecksum(for: file1)
        let checksum2 = try await engine.computeChecksum(for: file2)

        XCTAssertNotEqual(checksum1, checksum2)
    }
}
