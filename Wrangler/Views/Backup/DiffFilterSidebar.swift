import SwiftUI

struct DiffFilterSidebar: View {
    let summary: DiffSummary
    @Binding var selectedFilter: DiffStatus?

    var body: some View {
        List(selection: $selectedFilter) {
            Section("Filter") {
                // "All" uses nil — stored as Optional<DiffStatus>.none
                filterRow(
                    nil,
                    label: "All Files",
                    icon: "doc.on.doc",
                    count: summary.totalFiles,
                    color: .primary
                )

                Divider().listRowSeparator(.hidden)

                filterRow(.identical, label: "Identical",
                          icon: DiffStatus.identical.iconName,
                          count: summary.identicalCount, color: .green)

                filterRow(.newOnSource, label: "New on Source",
                          icon: DiffStatus.newOnSource.iconName,
                          count: summary.newOnSourceCount, color: .blue)

                filterRow(.modified, label: "Modified",
                          icon: DiffStatus.modified.iconName,
                          count: summary.modifiedCount, color: .orange)

                filterRow(.orphaned, label: "Orphaned",
                          icon: DiffStatus.orphaned.iconName,
                          count: summary.orphanedCount, color: .red)
            }

            Section("Sizes") {
                sizeRow("Source", summary.totalSourceSize)
                sizeRow("Destination", summary.totalDestinationSize)
                Divider().listRowSeparator(.hidden)
                sizeRow("To Transfer", summary.bytesToTransfer, bold: true)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Wrangler")
    }

    // MARK: - Rows

    private func filterRow(
        _ filter: DiffStatus?,
        label: String,
        icon: String,
        count: Int,
        color: Color
    ) -> some View {
        HStack(spacing: 0) {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .tag(filter)          // List uses this for selection
    }

    private func sizeRow(_ label: String, _ bytes: Int64, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(ByteCountFormatting.string(fromByteCount: bytes))
                .font(bold ? .caption.weight(.semibold) : .caption)
                .monospacedDigit()
        }
        .listRowSeparator(.hidden)
    }
}
