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

    /// Available capacity on the destination volume (uses important-usage key
    /// which accounts for purgeable space, same as Finder's "X GB available").
    var destinationAvailableBytes: Int64 {
        guard let destURL = destModel.currentURL else { return 0 }
        let values = try? destURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
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

        let filesToCopy: [(source: URL, destination: URL, relativePath: String, size: Int64)] =
            selectedFiles.compactMap { path in
                guard let sourceURL = sourceModel.currentURL else { return nil }
                let fullSourceURL = sourceURL.appendingPathComponent(path)
                let fullDestURL = destURL.appendingPathComponent(path)

                let attrs = try? FileManager.default.attributesOfItem(atPath: fullSourceURL.path)
                let size = (attrs?[.size] as? Int64) ?? 0

                return (fullSourceURL, fullDestURL, path, size)
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
