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

    /// Prompts the user for a name and creates a new sub-folder inside currentURL.
    /// Returns the new folder URL on success, nil otherwise.
    @discardableResult
    func createNewFolder(suggestedName: String = "New Folder") -> URL? {
        guard let base = currentURL else { return nil }

        // Use NSSavePanel configured as "new folder" dialog
        let panel = NSSavePanel()
        panel.title = "New Folder"
        panel.message = "Enter a name for the new folder:"
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.directoryURL = base
        panel.prompt = "Create"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            loadEntries()   // refresh
            return url
        } catch {
            return nil
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

        Task {
            let loaded: [FileEntry] = await Task.detached(priority: .userInitiated) {
                guard let contents = try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles]
                ) else { return [] }

                return contents.compactMap { fileURL -> FileEntry? in
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
            }.value

            await MainActor.run {
                self.entries = loaded
                self.sortEntries()
                self.isLoading = false
            }
        }
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
