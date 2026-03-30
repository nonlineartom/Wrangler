import SwiftUI

struct DiffView: View {
    @Bindable var session: BackupSession
    @State private var selectedEntryID: String?
    @State private var statusFilter: DiffStatus?
    @State private var showInspector = true
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            DiffFilterSidebar(
                summary: session.diffResult.summary,
                selectedFilter: $statusFilter
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } content: {
            VStack(spacing: 0) {
                // Media thumbnail grid
                if !session.thumbnails.isEmpty {
                    MediaThumbnailGrid(
                        entries: session.diffResult.entries,
                        thumbnails: session.thumbnails
                    ) { entry in
                        selectedEntryID = entry.id
                    }
                    .padding()

                    Divider()
                }

                // Diff tree
                DiffTreeView(
                    entries: filteredEntries,
                    selectedID: $selectedEntryID
                )

                Divider()

                // Bottom summary bar
                summaryBar
            }
            .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        } detail: {
            if let entryID = selectedEntryID,
               let entry = session.diffResult.entries.first(where: { $0.id == entryID }) {
                FileInspectorView(entry: entry)
            } else {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Choose a file from the tree to inspect its details")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Filter files...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await session.startSync() }
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!session.canStartSync)
            }

            ToolbarItem {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
            }
        }
    }

    private var filteredEntries: [DiffEntry] {
        var entries = session.diffResult.entries

        if let filter = statusFilter {
            entries = entries.filter { $0.status == filter }
        }

        if !searchText.isEmpty {
            entries = entries.filter {
                $0.fileName.localizedCaseInsensitiveContains(searchText) ||
                $0.relativePath.localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries
    }

    private var summaryBar: some View {
        HStack(spacing: 16) {
            let s = session.diffResult.summary

            Label("\(s.newOnSourceCount) new", systemImage: "plus.circle.fill")
                .foregroundStyle(.blue)
                .font(.caption)

            Label("\(s.modifiedCount) modified", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundStyle(.orange)
                .font(.caption)

            Label("\(s.identicalCount) identical", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)

            Label("\(s.orphanedCount) orphaned", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)

            Spacer()

            Text("\(ByteCountFormatting.string(fromByteCount: s.bytesToTransfer)) to transfer")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
