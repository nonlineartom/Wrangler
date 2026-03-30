import Foundation
import SwiftUI

@Observable
final class IngestSession {
    enum Phase {
        case browsing
        case copying
        case complete
    }

    var phase: Phase = .browsing
    var sourceModel = FileBrowserModel()
    var destModel = FileBrowserModel()
    var selectedFiles: Set<String> = []
    var copyProgress: CopyProgress = .idle
    var isCopying = false
    var completedFiles: [CompletedFile] = []
    var skippedFiles: [SkippedFile] = []
    var errors: [CopyError] = []

    var thumbnails: [String: NSImage] = [:]

    private let copyEngine = CopyEngine()
    private let thumbnailEngine = ThumbnailEngine()

    // MARK: - Space check

    /// Total bytes of all currently-selected source entries.
    var selectedTotalBytes: Int64 {
        sourceModel.entries
            .filter { selectedFiles.contains($0.relativePath) }
            .reduce(Int64(0)) { $0 + $1.fileSize }
    }

    /// Available capacity on the destination volume.
    var destinationAvailableBytes: Int64 {
        // destModel.volumeInfo is populated by VolumeDetector via FileBrowserModel.navigate()
        // and is the same value shown in the pane header — reliable for all volume types.
        if let cap = destModel.volumeInfo?.availableCapacity, cap > 0 { return cap }
        // Fallback: query the volume directly
        guard let destURL = destModel.currentURL else { return 0 }
        return VolumeDetector.volumeInfo(for: destURL)?.availableCapacity ?? 0
    }

    /// False when selected bytes exceed destination free space.
    var destinationHasSpace: Bool {
        guard !selectedFiles.isEmpty, destModel.currentURL != nil else { return true }
        return selectedTotalBytes <= destinationAvailableBytes
    }

    var canCopy: Bool {
        !selectedFiles.isEmpty && destModel.currentURL != nil && !isCopying && destinationHasSpace
    }

    func copySelectedFiles() async {
        guard let destURL = destModel.currentURL else { return }

        // Final space check — destination may have changed since the UI last polled
        guard destinationHasSpace else { return }

        isCopying = true
        phase = .copying
        copyProgress = .idle

        // Expand selected paths — recurse into directories so the copy engine
        // only ever sees individual files, not folder entries.
        var filesToCopy: [(source: URL, destination: URL, relativePath: String, size: Int64)] = []
        guard let sourceBase = sourceModel.currentURL else {
            isCopying = false; phase = .browsing; return
        }

        for path in selectedFiles {
            let srcURL = sourceBase.appendingPathComponent(path)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: srcURL.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                // Enumerate directory contents recursively
                let enumerator = FileManager.default.enumerator(
                    at: srcURL,
                    includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                while let fileURL = enumerator?.nextObject() as? URL {
                    var isFileDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isFileDir)
                    guard !isFileDir.boolValue else { continue }
                    let relPath = String(fileURL.path.dropFirst(sourceBase.path.count + 1))
                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map { Int64($0) } ?? 0
                    filesToCopy.append((fileURL, destURL.appendingPathComponent(relPath), relPath, size))
                }
            } else {
                let size = (try? srcURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map { Int64($0) } ?? 0
                filesToCopy.append((srcURL, destURL.appendingPathComponent(path), path, size))
            }
        }

        do {
            let result = try await copyEngine.copyFiles(
                files: filesToCopy,
                conflictPolicy: .skipExisting
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.copyProgress = progress
                }
            }

            await MainActor.run {
                self.completedFiles = result.completed
                self.skippedFiles  = result.skipped
                self.errors = self.copyProgress.errors
                self.isCopying = false
                self.phase = .complete
                self.selectedFiles.removeAll()
                // Refresh destination browser
                if let destURL = self.destModel.currentURL {
                    self.destModel.navigate(to: destURL)
                }
            }
        } catch {
            await MainActor.run {
                self.isCopying = false
                self.phase = .browsing
            }
        }
    }

    func cancelCopy() async {
        await copyEngine.cancel()
        isCopying = false
        phase = .browsing
    }

    func reset() {
        phase = .browsing
        completedFiles = []
        skippedFiles = []
        errors = []
        copyProgress = .idle
    }

    func loadThumbnails(for entries: [FileEntry], baseURL: URL) async {
        let mediaEntries = entries.filter(\.isMediaFile)
        let urls = mediaEntries.map { baseURL.appendingPathComponent($0.relativePath) }

        let thumbs = await thumbnailEngine.generateThumbnails(for: urls)

        await MainActor.run {
            for (path, image) in thumbs {
                let relativePath = path.replacingOccurrences(of: baseURL.path + "/", with: "")
                self.thumbnails[relativePath] = image
            }
        }
    }
}
