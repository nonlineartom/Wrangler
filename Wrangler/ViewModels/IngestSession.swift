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
    var errors: [CopyError] = []

    var thumbnails: [String: NSImage] = [:]

    private let copyEngine = CopyEngine()
    private let thumbnailEngine = ThumbnailEngine()

    var canCopy: Bool {
        !selectedFiles.isEmpty && destModel.currentURL != nil && !isCopying
    }

    func copySelectedFiles() async {
        guard let destURL = destModel.currentURL else { return }

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
            let completed = try await copyEngine.copyFiles(files: filesToCopy) { [weak self] progress in
                Task { @MainActor in
                    self?.copyProgress = progress
                }
            }

            await MainActor.run {
                self.completedFiles = completed
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
