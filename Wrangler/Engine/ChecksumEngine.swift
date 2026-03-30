import Foundation
import CryptoKit

actor ChecksumEngine {
    static let blockSize = 256 * 1024 // 256KB for checksum reads

    struct Progress: Sendable {
        let fileName: String
        let bytesProcessed: Int64
        let totalBytes: Int64

        var fraction: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(bytesProcessed) / Double(totalBytes)
        }
    }

    func computeChecksum(
        for url: URL,
        progressHandler: (@Sendable (Progress) -> Void)? = nil
    ) async throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? Int64) ?? 0
        let fileName = url.lastPathComponent

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        var bytesRead: Int64 = 0

        while true {
            try Task.checkCancellation()

            let data = handle.readData(ofLength: Self.blockSize)
            if data.isEmpty { break }

            hasher.update(data: data)
            bytesRead += Int64(data.count)

            progressHandler?(Progress(
                fileName: fileName,
                bytesProcessed: bytesRead,
                totalBytes: fileSize
            ))
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func computeChecksums(
        for urls: [URL],
        maxConcurrent: Int? = nil,
        progressHandler: (@Sendable (String, Progress) -> Void)? = nil
    ) async throws -> [String: String] {
        let concurrency = maxConcurrent ?? ProcessInfo.processInfo.activeProcessorCount
        var results: [String: String] = [:]

        try await withThrowingTaskGroup(of: (String, String).self) { group in
            var active = 0

            for url in urls {
                if active >= concurrency {
                    if let result = try await group.next() {
                        results[result.0] = result.1
                        active -= 1
                    }
                }

                group.addTask {
                    let checksum = try await self.computeChecksum(for: url) { progress in
                        progressHandler?(url.path, progress)
                    }
                    return (url.path, checksum)
                }
                active += 1
            }

            for try await result in group {
                results[result.0] = result.1
            }
        }

        return results
    }
}
