import Foundation
import CryptoKit

// MARK: - Conflict policy

/// Determines what CopyEngine does when a file already exists at the destination.
enum ConflictPolicy: Sendable {
    /// **Ingest default.** If the destination file already exists (as a complete
    /// file, not a partial), skip the copy entirely and record it as skipped.
    /// The existing file is never touched.
    case skipExisting

    /// **Backup default.** Overwrite using a safe three-step rename:
    ///   existing → .wrangler-prev
    ///   partial  → final
    ///   .wrangler-prev deleted on success / restored on failure
    /// Checksum is verified on the partial *before* the existing file is moved,
    /// so the original is never removed unless the new data is already confirmed good.
    case safeReplace
}

// MARK: - Result types

struct SkippedFile: Identifiable, Sendable {
    let id = UUID()
    let relativePath: String
    let reason: String      // human-readable, e.g. "Already exists at destination"
}

struct CopyResult: Sendable {
    let completed: [CompletedFile]
    let skipped: [SkippedFile]
}

// MARK: - Engine

actor CopyEngine {
    static let chunkSize    = 1024 * 1024      // 1 MB blocks
    static let partialSuffix = ".wrangler-partial"
    static let prevSuffix    = ".wrangler-prev"

    enum State: Sendable { case idle, copying, paused, completed, failed(Error) }

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

    func cancel()  { cancelled = true }
    func pause()   { state = .paused }
    func resume()  { if case .paused = state { state = .copying } }

    // MARK: - Main entry point

    func copyFiles(
        files: [(source: URL, destination: URL, relativePath: String, size: Int64)],
        conflictPolicy: ConflictPolicy = .skipExisting,
        progressHandler: @Sendable (CopyProgress) -> Void
    ) async throws -> CopyResult {

        cancelled = false
        state = .copying

        let totalBytes = files.reduce(Int64(0)) { $0 + $1.size }
        var overallTransferred: Int64 = 0
        var completedFiles: [CompletedFile] = []
        var skippedFiles:   [SkippedFile]   = []
        var errors:         [CopyError]     = []
        let startTime = Date.now

        for (index, file) in files.enumerated() {
            try Task.checkCancellation()
            if cancelled { throw WranglerError.cancelled }

            while case .paused = state {
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()
            }

            // ── Pre-flight: respect conflict policy ───────────────────────────
            let destExists = FileManager.default.fileExists(atPath: file.destination.path)

            if destExists {
                switch conflictPolicy {
                case .skipExisting:
                    // Never touch the existing file — record as skipped and move on.
                    skippedFiles.append(SkippedFile(
                        relativePath: file.relativePath,
                        reason: "Already exists at destination"
                    ))
                    overallTransferred += file.size
                    reportProgress(
                        files: files, index: index,
                        overallTransferred: overallTransferred, totalBytes: totalBytes,
                        startTime: startTime, completed: completedFiles,
                        errors: errors, progressHandler: progressHandler
                    )
                    continue

                case .safeReplace:
                    break   // handled below after checksum verification
                }
            }

            // ── Ensure destination directory ──────────────────────────────────
            do {
                let destDir = file.destination.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            } catch {
                errors.append(CopyError(relativePath: file.relativePath,
                                        message: "Could not create destination directory: \(error.localizedDescription)",
                                        isRetryable: false))
                continue
            }

            // ── Compute source checksum ───────────────────────────────────────
            let sourceChecksum: String
            do {
                sourceChecksum = try await checksumEngine.computeChecksum(for: file.source)
            } catch {
                errors.append(CopyError(relativePath: file.relativePath,
                                        message: "Could not read source: \(error.localizedDescription)",
                                        isRetryable: true))
                continue
            }

            // ── Write to .wrangler-partial ────────────────────────────────────
            let partialURL = URL(fileURLWithPath: file.destination.path + Self.partialSuffix)

            do {
                let transferred = try await writePartial(
                    source: file.source,
                    partialURL: partialURL,
                    fileSize: file.size,
                    relativePath: file.relativePath,
                    overallTransferred: overallTransferred,
                    totalBytes: totalBytes,
                    totalFiles: files.count,
                    completedCount: index,
                    startTime: startTime,
                    completedFiles: completedFiles,
                    errors: errors,
                    progressHandler: progressHandler
                )
                overallTransferred += transferred
            } catch {
                try? FileManager.default.removeItem(at: partialURL)
                errors.append(CopyError(relativePath: file.relativePath,
                                        message: error.localizedDescription,
                                        isRetryable: !(error is WranglerError)))
                continue
            }

            // ── Verify checksum of partial BEFORE touching the destination ────
            let partialChecksum: String
            do {
                partialChecksum = try await checksumEngine.computeChecksum(for: partialURL)
            } catch {
                try? FileManager.default.removeItem(at: partialURL)
                errors.append(CopyError(relativePath: file.relativePath,
                                        message: "Could not verify partial: \(error.localizedDescription)",
                                        isRetryable: true))
                continue
            }

            guard partialChecksum == sourceChecksum else {
                try? FileManager.default.removeItem(at: partialURL)
                errors.append(CopyError(relativePath: file.relativePath,
                                        message: "Checksum mismatch — file not copied",
                                        isRetryable: true))
                continue
            }

            // ── Safe rename: partial → final ──────────────────────────────────
            // Checksum is confirmed good. NOW we move the existing file out of
            // the way (safeReplace) and put the new one in place.
            let prevURL = URL(fileURLWithPath: file.destination.path + Self.prevSuffix)

            do {
                if FileManager.default.fileExists(atPath: file.destination.path) {
                    // safeReplace only — skipExisting already continued above.
                    // Clean up any stale .prev first.
                    try? FileManager.default.removeItem(at: prevURL)
                    // Move existing → .prev (our safety net)
                    try FileManager.default.moveItem(at: file.destination, to: prevURL)
                }

                // Move verified partial → final
                try FileManager.default.moveItem(at: partialURL, to: file.destination)

                // Success: discard the .prev backup
                try? FileManager.default.removeItem(at: prevURL)

            } catch {
                // Final rename failed — restore .prev if we moved it
                if FileManager.default.fileExists(atPath: prevURL.path) {
                    try? FileManager.default.moveItem(at: prevURL, to: file.destination)
                }
                try? FileManager.default.removeItem(at: partialURL)
                errors.append(CopyError(relativePath: file.relativePath,
                                        message: "Could not finalise file: \(error.localizedDescription)",
                                        isRetryable: true))
                continue
            }

            // ── Preserve modification date ────────────────────────────────────
            if let modDate = try? file.source
                .resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate {
                try? FileManager.default.setAttributes(
                    [.modificationDate: modDate],
                    ofItemAtPath: file.destination.path
                )
            }

            completedFiles.append(CompletedFile(
                relativePath: file.relativePath,
                fileSize: file.size,
                checksum: sourceChecksum,
                verified: true
            ))

            reportProgress(
                files: files, index: index + 1,
                overallTransferred: overallTransferred, totalBytes: totalBytes,
                startTime: startTime, completed: completedFiles,
                errors: errors, progressHandler: progressHandler
            )
        }

        state = errors.isEmpty ? .completed : .failed(
            WranglerError.copyFailed(file: "multiple", underlying: NSError(domain: "Wrangler", code: -1))
        )
        return CopyResult(completed: completedFiles, skipped: skippedFiles)
    }

    // MARK: - Write partial file (with resume)

    private func writePartial(
        source: URL,
        partialURL: URL,
        fileSize: Int64,
        relativePath: String,
        overallTransferred: Int64,
        totalBytes: Int64,
        totalFiles: Int,
        completedCount: Int,
        startTime: Date,
        completedFiles: [CompletedFile],
        errors: [CopyError],
        progressHandler: @Sendable (CopyProgress) -> Void
    ) async throws -> Int64 {

        var bytesAlreadyWritten: Int64 = 0

        // Check for existing partial (resume support)
        if FileManager.default.fileExists(atPath: partialURL.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: partialURL.path)
            bytesAlreadyWritten = (attrs[.size] as? Int64) ?? 0
        }

        let sourceHandle = try FileHandle(forReadingFrom: source)
        defer { try? sourceHandle.close() }

        let destHandle: FileHandle
        if bytesAlreadyWritten > 0 {
            sourceHandle.seek(toFileOffset: UInt64(bytesAlreadyWritten))
            destHandle = try FileHandle(forWritingTo: partialURL)
            destHandle.seekToEndOfFile()
        } else {
            FileManager.default.createFile(atPath: partialURL.path, contents: nil)
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

            try destHandle.write(contentsOf: data)
            currentBytes += Int64(data.count)

            let blocksCompleted = Int(ceil(Double(currentBytes) / Double(Self.chunkSize)))

            progressHandler(CopyProgress(
                totalFiles: totalFiles,
                completedFiles: completedCount,
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

        return currentBytes - bytesAlreadyWritten
    }

    // MARK: - Progress helper

    private func reportProgress(
        files: [(source: URL, destination: URL, relativePath: String, size: Int64)],
        index: Int,
        overallTransferred: Int64,
        totalBytes: Int64,
        startTime: Date,
        completed: [CompletedFile],
        errors: [CopyError],
        progressHandler: @Sendable (CopyProgress) -> Void
    ) {
        progressHandler(CopyProgress(
            totalFiles: files.count,
            completedFiles: index,
            totalBytes: totalBytes,
            transferredBytes: overallTransferred,
            currentFileName: "",
            currentFileSize: 0,
            currentFileBytesTransferred: 0,
            currentFileBlocksTotal: 0,
            currentFileBlocksCompleted: 0,
            startTime: startTime,
            errors: errors,
            completedFileNames: completed
        ))
    }
}
