import SwiftUI

struct FileBrowserPane: View {
    @Bindable var model: FileBrowserModel
    let label: String
    @Binding var selectedFiles: Set<String>
    let allowSelection: Bool
    let thumbnails: [String: NSImage]
    var onNavigate: ((URL) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Header with volume info
            paneHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

            Divider()

            // Breadcrumb bar
            if !model.breadcrumbs.isEmpty {
                breadcrumbBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.background.opacity(0.5))

                Divider()
            }

            // File list
            if model.currentURL != nil {
                fileList
            } else {
                emptyState
            }
        }
    }

    private var paneHeader: some View {
        HStack {
            Label(label, systemImage: label == "Source" ? "externaldrive.fill" : "folder.fill")
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            if let vi = model.volumeInfo {
                CapacityBarView(usage: vi.usagePercent)
                    .frame(width: 50, height: 5)

                Text("\(ByteCountFormatting.string(fromByteCount: vi.availableCapacity)) free")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                model.selectDirectory()
                if let url = model.currentURL {
                    onNavigate?(url)
                }
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Picker("Sort", selection: Binding(
                get: { model.sortOrder },
                set: { model.sortOrder = $0; model.sortEntries() }
            )) {
                Text("Name").tag(FileBrowserModel.SortOrder.name)
                Text("Date").tag(FileBrowserModel.SortOrder.date)
                Text("Size").tag(FileBrowserModel.SortOrder.size)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(model.breadcrumbs.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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

    private var fileList: some View {
        List(model.entries, selection: allowSelection ? $selectedFiles : .constant([])) { entry in
            FileRowView(
                entry: entry,
                thumbnail: thumbnails[entry.relativePath]
            )
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if entry.isDirectory, let url = model.currentURL {
                    let newURL = url.appendingPathComponent(entry.fileName)
                    model.navigate(to: newURL)
                    onNavigate?(newURL)
                }
            }
            .onTapGesture(count: 1) {
                if allowSelection && !entry.isDirectory {
                    if selectedFiles.contains(entry.relativePath) {
                        selectedFiles.remove(entry.relativePath)
                    } else {
                        selectedFiles.insert(entry.relativePath)
                    }
                }
            }
            .tag(entry.relativePath)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No directory selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Browse...") {
                model.selectDirectory()
                if let url = model.currentURL {
                    onNavigate?(url)
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
