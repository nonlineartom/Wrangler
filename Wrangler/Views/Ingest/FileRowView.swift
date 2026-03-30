import SwiftUI

struct FileRowView: View {
    let entry: FileEntry
    let thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            // Icon or thumbnail
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(iconColor)
                        .frame(width: 32, height: 22)
                }
            }

            // File info
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.fileName)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !entry.isDirectory {
                        Text(ByteCountFormatting.string(fromByteCount: entry.fileSize))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(DateFormatting.displayString(from: entry.modificationDate))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if !entry.isDirectory {
                Text(fileExtension)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        if entry.isDirectory { return "folder.fill" }
        if entry.isVideoFile { return "film" }
        if entry.isImageFile { return "photo" }
        return "doc.fill"
    }

    private var iconColor: Color {
        if entry.isDirectory { return .accentColor }
        if entry.isMediaFile { return .purple }
        return .secondary
    }

    private var fileExtension: String {
        (entry.fileName as NSString).pathExtension.uppercased()
    }
}
