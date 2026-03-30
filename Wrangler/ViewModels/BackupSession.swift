import Foundation
import SwiftUI

@Observable
final class BackupSession {
    enum Phase {
        case setup
        case scanning
        case diffReview
        case syncing
        case dashboard
    }

    var phase: Phase = .setup
    var sourceURL: URL?
    var destinationURL: URL?
    var diffResult: DiffResult = .empty
    var scanProgress: DiffEngine.ScanProgress?
    var copyProgress: CopyProgress = .idle
    var syncReport: SyncReport?
    var error: WranglerError?
    var showError = false

    private let diffEngine = DiffEngine()
    private let copyEngine = CopyEngine()
    private let thumbnailEngine = ThumbnailEngine()

    var thumbnails: [String: NSImage] = [:]
    var isScanning = false
    var isSyncing = false

    // Quick directory listings for treemap (populated when directories are selected)
    var sourceEntries: [FileEntry] = []
    var destEntries: [FileEntry] = []

    var canStartScan: Bool {
        guard let src = sourceURL, let dest = destinationURL, !isScanning else { return false }
        return src.standardized.path != dest.standardized.path
    }

    var canStartSync: Bool {
        !diffResult.entries.isEmpty &&
        (diffResult.summary.newOnSourceCount > 0 || diffResult.summary.modifiedCount > 0) &&
        !isSyncing
    }

    func quickScan(url: URL) async -> [FileEntry] {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var entries: [FileEntry] = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
            let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
            entries.append(FileEntry(
                relativePath: relativePath,
                fileName: values.name ?? fileURL.lastPathComponent,
                isDirectory: values.isDirectory ?? false,
                fileSize: Int64(values.fileSize ?? 0),
                modificationDate: values.contentModificationDate ?? .distantPast
            ))
        }
        return entries
    }

    func loadSourceEntries() async {
        guard let url = sourceURL else { sourceEntries = []; return }
        let entries = await quickScan(url: url)
        await MainActor.run { sourceEntries = entries }
    }

    func loadDestEntries() async {
        guard let url = destinationURL else { destEntries = []; return }
        let entries = await quickScan(url: url)
        await MainActor.run { destEntries = entries }
    }

    func startScan() async {
        guard let source = sourceURL, let dest = destinationURL else { return }

        isScanning = true
        phase = .scanning
        scanProgress = nil

        do {
            let result = try await diffEngine.compare(
                source: source,
                destination: dest
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.scanProgress = progress
                }
            }

            await MainActor.run {
                self.diffResult = result
                self.phase = .diffReview
                self.isScanning = false
            }

            // Generate thumbnails in background
            await generateThumbnails(source: source)

        } catch {
            await MainActor.run {
                self.error = .scanFailed(underlying: error)
                self.showError = true
                self.isScanning = false
                self.phase = .setup
            }
        }
    }

    func startSync() async {
        guard let source = sourceURL, let dest = destinationURL else { return }

        isSyncing = true
        phase = .syncing
        copyProgress = .idle

        let filesToSync = diffResult.entries.filter {
            $0.status == .newOnSource || $0.status == .modified
        }

        let copyItems = filesToSync.compactMap { entry -> (source: URL, destination: URL, relativePath: String, size: Int64)? in
            guard let srcEntry = entry.sourceEntry else { return nil }
            return (
                source: source.appendingPathComponent(entry.relativePath),
                destination: dest.appendingPathComponent(entry.relativePath),
                relativePath: entry.relativePath,
                size: srcEntry.fileSize
            )
        }

        let modDateLookup: [String: Date] = Dictionary(
            uniqueKeysWithValues: filesToSync.compactMap { entry -> (String, Date)? in
                guard let srcEntry = entry.sourceEntry else { return nil }
                return (entry.relativePath, srcEntry.modificationDate)
            }
        )

        let startTime = Date.now

        do {
            let result = try await copyEngine.copyFiles(
                files: copyItems,
                conflictPolicy: .safeReplace
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.copyProgress = progress
                }
            }

            let completed = result.completed
            let duration = Date.now.timeIntervalSince(startTime)

            let report = SyncReport(
                timestamp: .now,
                sourceRoot: source,
                destinationRoot: dest,
                duration: duration,
                averageThroughput: copyProgress.throughputBytesPerSecond,
                filesCopied: completed.map { file in
                    SyncedFileRecord(
                        relativePath: file.relativePath,
                        fileSize: file.fileSize,
                        modificationDate: modDateLookup[file.relativePath] ?? .now,
                        ownerName: nil,
                        action: .copied,
                        checksum: file.checksum
                    )
                },
                filesUpdated: [],
                filesSkipped: diffResult.entries.filter { $0.status == .identical }.map { entry in
                    SyncedFileRecord(
                        relativePath: entry.relativePath,
                        fileSize: entry.sourceEntry?.fileSize ?? 0,
                        modificationDate: entry.sourceEntry?.modificationDate ?? .now,
                        ownerName: entry.sourceEntry?.ownerName,
                        action: .skipped,
                        checksum: entry.sourceEntry?.checksum
                    )
                },
                filesDeleted: [],
                errors: copyProgress.errors,
                totalBytesTransferred: copyProgress.transferredBytes,
                allVerified: completed.allSatisfy(\.verified)
            )

            await MainActor.run {
                self.syncReport = report
                self.isSyncing = false
                self.phase = .dashboard
            }

        } catch {
            await MainActor.run {
                self.error = .copyFailed(file: "sync", underlying: error)
                self.showError = true
                self.isSyncing = false
            }
        }
    }

    func cancelSync() async {
        await copyEngine.cancel()
        isSyncing = false
    }

    func reset() {
        phase = .setup
        diffResult = .empty
        copyProgress = .idle
        syncReport = nil
        scanProgress = nil
        thumbnails = [:]
    }

    private func generateThumbnails(source: URL) async {
        let mediaFiles = diffResult.entries
            .filter { $0.sourceEntry?.isMediaFile == true }
            .compactMap { entry -> URL? in
                source.appendingPathComponent(entry.relativePath)
            }

        let thumbs = await thumbnailEngine.generateThumbnails(for: mediaFiles)

        await MainActor.run {
            for (path, image) in thumbs {
                let relativePath = path.replacingOccurrences(of: source.path + "/", with: "")
                self.thumbnails[relativePath] = image
            }
        }
    }
}
