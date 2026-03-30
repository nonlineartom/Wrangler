import SwiftUI

struct DiffFilterSidebar: View {
    let summary: DiffSummary
    @Binding var selectedFilter: DiffStatus?

    var body: some View {
        List(selection: $selectedFilter) {
            Section("Filter") {
                filterRow(label: "All Files", icon: "doc.on.doc", count: summary.totalFiles, filter: nil)

                Divider()

                filterRow(label: "Identical", icon: DiffStatus.identical.iconName, count: summary.identicalCount, filter: .identical, color: .green)

                filterRow(label: "New", icon: DiffStatus.newOnSource.iconName, count: summary.newOnSourceCount, filter: .newOnSource, color: .blue)

                filterRow(label: "Modified", icon: DiffStatus.modified.iconName, count: summary.modifiedCount, filter: .modified, color: .orange)

                filterRow(label: "Orphaned", icon: DiffStatus.orphaned.iconName, count: summary.orphanedCount, filter: .orphaned, color: .red)
            }

            Section("Summary") {
                VStack(alignment: .leading, spacing: 6) {
                    summaryRow("Source", ByteCountFormatting.string(fromByteCount: summary.totalSourceSize))
                    summaryRow("Destination", ByteCountFormatting.string(fromByteCount: summary.totalDestinationSize))
                    Divider()
                    summaryRow("To Transfer", ByteCountFormatting.string(fromByteCount: summary.bytesToTransfer))
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
    }

    private func filterRow(label: String, icon: String, count: Int, filter: DiffStatus?, color: Color = .primary) -> some View {
        Button {
            selectedFilter = filter
        } label: {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundStyle(filter == selectedFilter ? .primary : color)

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .background(
            filter == selectedFilter ?
                RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.1)) :
                RoundedRectangle(cornerRadius: 6).fill(.clear)
        )
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
    }
}
