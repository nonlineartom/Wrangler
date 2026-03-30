import SwiftUI

struct MediaThumbnailGrid: View {
    let entries: [DiffEntry]
    let thumbnails: [String: NSImage]
    var onSelect: ((DiffEntry) -> Void)?

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 160), spacing: 8)]

    var body: some View {
        DisclosureGroup {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(mediaEntries) { entry in
                        MediaThumbnailCell(
                            entry: entry,
                            thumbnail: thumbnails[entry.relativePath]
                        )
                        .onTapGesture {
                            onSelect?(entry)
                        }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 240)
        } label: {
            Label("Media Preview (\(mediaEntries.count) files)", systemImage: "photo.on.rectangle.angled")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private var mediaEntries: [DiffEntry] {
        entries.filter { $0.sourceEntry?.isMediaFile == true }
    }
}

struct MediaThumbnailCell: View {
    let entry: DiffEntry
    let thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(.quaternary)

                        Image(systemName: entry.sourceEntry?.isVideoFile == true ? "film" : "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: 120, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(entry.status.color, lineWidth: 2)
            )

            VStack(spacing: 1) {
                Text(entry.fileName)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(parentFolder(of: entry.relativePath))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(width: 130)
    }

    private func parentFolder(of path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 1 {
            return String(components[components.count - 2])
        }
        return ""
    }
}

// Simplified version for Ingest mode (no diff status)
struct IngestThumbnailCell: View {
    let entry: FileEntry
    let thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(.quaternary)
                        Image(systemName: entry.isVideoFile ? "film" : "photo")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: 120, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(entry.fileName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 130)
    }
}
