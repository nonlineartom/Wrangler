import Foundation
import CryptoKit

actor CopyEngine {
    static let chunkSize = 1024 * 1024 // 1MB blocks
    static let partialSuffix = ".wrangler-partial"

    enum State: Sendable {
        case idle
        case copying
        case paused
        case completed
        case failed(Error)
    }

    struct FileTransferProgress: Sendable {
        let relativePath: String
        let totalBytes: Int64
        let transferredBytes: Int64
        let blocksTotal: Int
        let blocksCompleted: Int
        let sourceChecksum: String?
    }

    private var state: State = .idle
    private var cancelled = false
    private let checksumEngine = ChecksumEngine()

    func cancel() {
        cancelled = true
    }

    func pause() {
        state = .paused
    }

    func resume() {
        if case .paused = state {
            state = .copying
        }
    }

    func copyFiles(
        files: [(source: URL, destination: URL, relativePath: String, size: Int64)],
        progressHandler: @Sendable (CopyProgress) -> Void
    ) async throws -> [CompletedFile] {
        cancelled = false
        state = .copying

        let totalBytes = files.reduce(Int64(0)) { $0 + $1.size }
        var overallTransferred: Int64 = 0
        var completedFiles: [CompletedFile] = []
        var errors: [CopyError] = []
        let startTime = Date.now

        for (index, file) in files.enumerated() {
            try Task.checkCancellation()
            if cancelled { throw WranglerError.cancelled }

            while case .paused = state {
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()
            }

            do {
                // Ensure destination directory exists
                let destDir = file.destination.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

                // Compute source checksum
                let sourceChecksum = try await checksumEngine.computeChecksum(for: file.source)

                // Copy with resume support
                let bytesAlreadyTransferred = try await copyFileWithResume(
                    source: file.source,
                    destination: file.destination,
                    relativePath: file.relativePath,
                    fileSize: file.size,
                    overallTransferred: overallTransferred,
                    totalBytes: totalBytes,
                    totalFiles: files.count,
                    completedFileCount: index,
                    startTime: startTime,
                    completedFiles: completedFiles,
                    errors: errors,
                    progressHandler: progressHandler
                )

                overallTransferred += bytesAlreadyTransferred

                // Post-copy verification
                let destChecksum = try await checksumEngine.computeChecksum(for: file.destination)

                let verified = sourceChecksum == destChecksum
                if !verified {
                    // Checksum mismatch — delete and retry once
                    try? FileManager.default.removeItem(at: file.destination)
                    throw WranglerError.checksumMismatch(
                        file: file.relativePath,
                        expected: sourceChecksum,
                        actual: destChecksum
                    )
                }

                // Preserve modification date
                try FileManager.default.setAttributes(
                    [.modificationDate: file.source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.now],
                    ofItemAtPath: file.destination.path
                )

                completedFiles.append(CompletedFile(
                    relativePath: file.relativePath,
                    fileSize: file.size,
                    checksum: sourceChecksum,
                    verified: true
                ))

            } catch {
                let copyError = CopyError(
                    relativePath: file.relativePath,
                    message: error.localizedDescription,
                    isRetryable: !(error is WranglerError)
                )
                errors.append(copyError)
                overallTransferred += file.size
            }

            // Report progress after each file
            progressHandler(CopyProgress(
                totalFiles: files.count,
                completedFiles: completedFiles.count + errors.count,
                totalBytes: totalBytes,
                transferredBytes: overallTransferred,
                currentFileName: "",
                currentFileSize: 0,
                currentFileBytesTransferred: 0,
                currentFileBlocksTotal: 0,
                currentFileBlocksCompleted: 0,
                startTime: startTime,
                errors: errors,
                completedFileNames: completedFiles
            ))
        }

        state = errors.isEmpty ? .completed : .failed(WranglerError.copyFailed(file: "multiple", underlying: NSError(domain: "Wrangler", code: -1)))
        return completedFiles
    }

    private func copyFileWithResume(
        source: URL,
        destination: URL,
        relativePath: String,
        fileSize: Int64,
        overallTransferred: Int64,
        totalBytes: Int64,
        totalFiles: Int,
        completedFileCount: Int,
        startTime: Date,
        completedFiles: [CompletedFile],
        errors: [CopyError],
        progressHandler: @Sendable (CopyProgress) -> Void
    ) async throws -> Int64 {
        let partialPath = destination.path + Self.partialSuffix
        let partialURL = URL(fileURLWithPath: partialPath)

        var bytesAlreadyWritten: Int64 = 0

        // Check for existing partial file
        if FileManager.default.fileExists(atPath: partialPath) {
            let attrs = try FileManager.default.attributesOfItem(atPath: partialPath)
            bytesAlreadyWritten = (attrs[.size] as? Int64) ?? 0
        }

        let sourceHandle = try FileHandle(forReadingFrom: source)
        defer { try? sourceHandle.close() }

        let destHandle: FileHandle
        if bytesAlreadyWritten > 0 {
            // Resume: seek source to where we left off, open dest for appending
            sourceHandle.seek(toFileOffset: UInt64(bytesAlreadyWritten))
            destHandle = try FileHandle(forWritingTo: partialURL)
            destHandle.seekToEndOfFile()
        } else {
            // Fresh copy
            FileManager.default.createFile(atPath: partialPath, contents: nil)
            destHandle = try FileHandle(forWritingTo: partialURL)
        }
        defer { try? destHandle.close() }

        let blocksTotal = Int(ceil(Double(fileSize) / Double(Self.chunkSize)))
        var currentBytes = bytesAlreadyWritten

        while currentBytes < fileSize {
            try Task.checkCancellation()
            if cancelled { throw WranglerError.cancelled }

            while case .paused = state {
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()
            }

            let data = sourceHandle.readData(ofLength: Self.chunkSize)
            if data.isEmpty { break }

            destHandle.write(data)
            currentBytes += Int64(data.count)

            let blocksCompleted = Int(ceil(Double(currentBytes) / Double(Self.chunkSize)))

            progressHandler(CopyProgress(
                totalFiles: totalFiles,
                completedFiles: completedFileCount,
                totalBytes: totalBytes,
                transferredBytes: overallTransferred + currentBytes,
                currentFileName: relativePath,
                currentFileSize: fileSize,
                currentFileBytesTransferred: currentBytes,
                currentFileBlocksTotal: blocksTotal,
                currentFileBlocksCompleted: blocksCompleted,
                startTime: startTime,
                errors: errors,
                completedFileNames: completedFiles
            ))
        }

        try destHandle.close()

        // Rename partial to final
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: partialURL, to: destination)

        return fileSize
    }
}
