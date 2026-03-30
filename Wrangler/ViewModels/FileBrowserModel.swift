import Foundation
import AppKit

@Observable
final class FileBrowserModel {
    var currentURL: URL?
    var entries: [FileEntry] = []
    var breadcrumbs: [BreadcrumbItem] = []
    var volumeInfo: VolumeInfo?
    var isLoading = false
    var sortOrder: SortOrder = .name
    var viewMode: ViewMode = .list

    enum SortOrder {
        case name, date, size

        var label: String {
            switch self {
            case .name: "Name"
            case .date: "Date"
            case .size: "Size"
            }
        }
    }

    enum ViewMode {
        case list, grid
    }

    struct BreadcrumbItem: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
    }

    func navigate(to url: URL) {
        currentURL = url
        volumeInfo = VolumeDetector.volumeInfo(for: url)
        loadEntries()
        buildBreadcrumbs()
    }

    func navigateUp() {
        guard let current = currentURL, current.pathComponents.count > 2 else { return }
        navigate(to: current.deletingLastPathComponent())
    }

    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory"

        if panel.runModal() == .OK, let url = panel.url {
            navigate(to: url)
        }
    }

    private func loadEntries() {
        guard let url = currentURL else { return }

        isLoading = true

        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isDirectoryKey,
            .nameKey
        ]

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )

            entries = contents.compactMap { fileURL in
                guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { return nil }

                return FileEntry(
                    relativePath: fileURL.lastPathComponent,
                    fileName: values.name ?? fileURL.lastPathComponent,
                    isDirectory: values.isDirectory ?? false,
                    fileSize: Int64(values.fileSize ?? 0),
                    modificationDate: values.contentModificationDate ?? .distantPast,
                    creationDate: values.creationDate,
                    ownerName: FileManager.default.ownerOfItem(atPath: fileURL.path)
                )
            }

            sortEntries()
        } catch {
            entries = []
        }

        isLoading = false
    }

    func sortEntries() {
        entries.sort { a, b in
            // Directories first
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }

            switch sortOrder {
            case .name:
                return a.fileName.localizedStandardCompare(b.fileName) == .orderedAscending
            case .date:
                return a.modificationDate > b.modificationDate
            case .size:
                return a.fileSize > b.fileSize
            }
        }
    }

    private func buildBreadcrumbs() {
        guard let url = currentURL else {
            breadcrumbs = []
            return
        }

        var items: [BreadcrumbItem] = []
        var current = url

        while current.pathComponents.count > 1 {
            items.insert(BreadcrumbItem(name: current.lastPathComponent, url: current), at: 0)
            current = current.deletingLastPathComponent()
        }

        breadcrumbs = items
    }
}
