import SwiftUI

struct DiffRowView: View {
    let entry: DiffEntry

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: entry.status.iconName)
                .foregroundStyle(entry.status.color)
                .font(.subheadline)

            // File icon
            Image(systemName: entry.isDirectory ? "folder.fill" : fileIcon)
                .foregroundStyle(entry.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            // File info
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                if entry.relativePath.contains("/") {
                    Text(parentPath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer()

            // Size
            if !entry.isDirectory {
                Text(entry.displaySize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Date
            if let date = entry.displayDate {
                Text(DateFormatting.shortString(from: date))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            // Status badge
            Text(entry.status.label)
                .font(.caption2)
                .foregroundStyle(entry.status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(entry.status.color.opacity(0.1), in: Capsule())
        }
        .padding(.vertical, 2)
    }

    private var fileIcon: String {
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        if FileEntry.videoExtensions.contains(ext) { return "film" }
        if FileEntry.imageExtensions.contains(ext) { return "photo" }
        return "doc.fill"
    }

    private var parentPath: String {
        let components = entry.relativePath.split(separator: "/")
        if components.count > 1 {
            return components.dropLast().joined(separator: "/")
        }
        return ""
    }
}
