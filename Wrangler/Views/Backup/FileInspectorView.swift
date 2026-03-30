import SwiftUI

struct FileInspectorView: View {
    let entry: DiffEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // File header
                HStack(spacing: 12) {
                    Image(systemName: entry.status.iconName)
                        .font(.title)
                        .foregroundStyle(entry.status.color)

                    VStack(alignment: .leading) {
                        Text(entry.fileName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(entry.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                // Status badge
                HStack {
                    Text(entry.status.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(entry.status.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(entry.status.color.opacity(0.1), in: Capsule())

                    Spacer()
                }

                Divider()

                // Side-by-side comparison
                if entry.sourceEntry != nil || entry.destinationEntry != nil {
                    HStack(alignment: .top, spacing: 16) {
                        if let src = entry.sourceEntry {
                            attributeColumn(title: "Source", entry: src)
                        }

                        if entry.sourceEntry != nil && entry.destinationEntry != nil {
                            Divider()
                        }

                        if let dst = entry.destinationEntry {
                            attributeColumn(title: "Destination", entry: dst)
                        }
                    }
                }
            }
            .padding()
        }
        .background(.background)
    }

    private func attributeColumn(title: String, entry: FileEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Group {
                attributeRow("Size", ByteCountFormatting.string(fromByteCount: entry.fileSize))
                attributeRow("Modified", DateFormatting.displayString(from: entry.modificationDate))

                if let created = entry.creationDate {
                    attributeRow("Created", DateFormatting.displayString(from: created))
                }

                if let owner = entry.ownerName {
                    attributeRow("Owner", owner)
                }

                if let checksum = entry.checksum {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SHA256")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(checksum)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attributeRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Text(value)
                .font(.caption)
        }
    }
}
