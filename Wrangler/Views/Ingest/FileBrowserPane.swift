import SwiftUI

struct FileBrowserPane: View {
    @Bindable var model: FileBrowserModel
    let label: String
    @Binding var selectedFiles: Set<String>
    let allowSelection: Bool
    let thumbnails: [String: NSImage]
    var onNavigate: ((URL) -> Void)?

    @State private var connectionInfo: DriveConnectionInfo?

    var body: some View {
        VStack(spacing: 0) {
            paneHeader
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)

            // Breadcrumbs
            if !model.breadcrumbs.isEmpty {
                breadcrumbBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(.windowBackgroundColor).opacity(0.6))
                Divider()
            } else {
                Divider()
            }

            // Sort bar — lives just above the list so it doesn't crowd the header
            if model.currentURL != nil {
                sortBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(.windowBackgroundColor).opacity(0.3))
                Divider()
            }

            // Content
            if model.currentURL != nil {
                fileList
            } else {
                emptyState
            }
        }
        .task(id: model.currentURL) {
            guard let url = model.currentURL else { connectionInfo = nil; return }
            connectionInfo = DriveConnectionDetector.detect(for: url)
        }
    }

    // MARK: - Header

    private var paneHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: label == "Source" ? "externaldrive.fill" : "folder.fill")
                .font(.subheadline)
                .foregroundStyle(.tint)

            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)

            if let conn = connectionInfo {
                ConnectionBadge(info: conn)
            }

            Spacer()

            if let vi = model.volumeInfo {
                HStack(spacing: 5) {
                    CapacityBarView(usage: vi.usagePercent)
                        .frame(width: 40, height: 4)
                    Text("\(ByteCountFormatting.string(fromByteCount: vi.availableCapacity)) free")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // New folder — only visible when browsing a directory
            if model.currentURL != nil {
                Button {
                    model.createNewFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("New folder inside current directory")
            }

            Button {
                model.selectDirectory()
                if let url = model.currentURL { onNavigate?(url) }
            } label: {
                Image(systemName: "folder")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open folder")
        }
    }

    // MARK: - Sort bar

    private var sortBar: some View {
        HStack {
            Text("\(model.entries.count) items")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Spacer()

            Picker("Sort", selection: Binding(
                get: { model.sortOrder },
                set: { model.sortOrder = $0; model.sortEntries() }
            )) {
                Text("Name").tag(FileBrowserModel.SortOrder.name)
                Text("Date").tag(FileBrowserModel.SortOrder.date)
                Text("Size").tag(FileBrowserModel.SortOrder.size)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 140)
        }
    }

    // MARK: - Breadcrumbs

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(model.breadcrumbs.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.quaternary)
                    }
                    Button(item.name) {
                        model.navigate(to: item.url)
                        onNavigate?(item.url)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(
                        index == model.breadcrumbs.count - 1 ? .primary : .secondary
                    )
                }
            }
        }
    }

    // MARK: - File list
    // Manual tap-based selection — List(selection:) requires prior keyboard focus on
    // macOS and misses the first click. We manage selectedFiles ourselves so the very
    // first click on any row registers immediately.

    private var fileList: some View {
        List(model.entries) { entry in
            FileRowView(
                entry: entry,
                isSelected: selectedFiles.contains(entry.relativePath),
                thumbnail: thumbnails[entry.relativePath],
                baseURL: model.currentURL
            )
            // Double-tap: navigate into directory
            .onTapGesture(count: 2) {
                guard entry.isDirectory, let url = model.currentURL else { return }
                let newURL = url.appendingPathComponent(entry.fileName)
                model.navigate(to: newURL)
                onNavigate?(newURL)
            }
            // Single-tap: toggle selection (files and folders)
            .onTapGesture(count: 1) {
                guard allowSelection else { return }
                if selectedFiles.contains(entry.relativePath) {
                    selectedFiles.remove(entry.relativePath)
                } else {
                    selectedFiles.insert(entry.relativePath)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Folder Selected", systemImage: "folder.badge.questionmark")
        } description: {
            Text("Choose a folder to browse its contents")
        } actions: {
            Button("Browse…") {
                model.selectDirectory()
                if let url = model.currentURL { onNavigate?(url) }
            }
            .buttonStyle(.bordered)
        }
    }
}
