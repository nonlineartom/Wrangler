import SwiftUI
import AppKit

struct FileRowView: View {
    let entry: FileEntry
    let thumbnail: NSImage?
    var baseURL: URL?          // needed for "Reveal in Finder"

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Icon / thumbnail
            ZStack {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        )
                    // Video play badge
                    if entry.isVideoFile {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(iconBackgroundColor)
                        .frame(width: 44, height: 30)
                    Image(systemName: iconName)
                        .font(.system(size: 13))
                        .foregroundStyle(iconForegroundColor)
                }
            }
            .frame(width: 44, height: 30)

            // Name + metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if !entry.isDirectory {
                        Text(ByteCountFormatting.string(fromByteCount: entry.fileSize))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Text("·").font(.caption2).foregroundStyle(.quaternary)
                    }
                    Text(DateFormatting.displayString(from: entry.modificationDate))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 4)

            // File-type badge (right-aligned, colour-coded)
            if !entry.isDirectory {
                Text(fileExtension)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(badgeTextColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(badgeBackgroundColor, in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.05) : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu { contextMenuContent }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if let url = fullURL {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }

        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(entry.relativePath, forType: .string)
        } label: {
            Label("Copy Relative Path", systemImage: "doc.on.clipboard")
        }

        if let url = fullURL {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            } label: {
                Label("Copy Full Path", systemImage: "doc.on.doc")
            }
        }

        if !entry.isDirectory {
            Divider()
            Button {
                if let url = fullURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("Open with Default App", systemImage: "arrow.up.forward.app")
            }
        }
    }

    // MARK: - Computed

    private var fullURL: URL? {
        baseURL?.appendingPathComponent(entry.relativePath)
    }

    private var iconName: String {
        if entry.isDirectory { return "folder.fill" }
        if entry.isVideoFile { return "film" }
        if entry.isImageFile { return "photo" }
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "wav", "aif", "aiff", "mp3", "m4a": return "waveform"
        case "pdf": return "doc.richtext"
        case "prproj", "aep", "drp": return "film.stack"
        default: return "doc.fill"
        }
    }

    private var iconBackgroundColor: Color {
        if entry.isDirectory { return .accentColor.opacity(0.12) }
        if entry.isVideoFile  { return .purple.opacity(0.12) }
        if entry.isImageFile  { return .blue.opacity(0.12) }
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "wav", "aif", "aiff", "mp3", "m4a": return .pink.opacity(0.12)
        case "prproj", "aep", "drp": return .orange.opacity(0.12)
        default: return Color(.separatorColor).opacity(0.2)
        }
    }

    private var iconForegroundColor: Color {
        if entry.isDirectory { return .accentColor }
        if entry.isVideoFile  { return .purple }
        if entry.isImageFile  { return .blue }
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "wav", "aif", "aiff", "mp3", "m4a": return .pink
        case "prproj", "aep", "drp": return .orange
        default: return .secondary
        }
    }

    private var fileExtension: String {
        (entry.fileName as NSString).pathExtension.uppercased()
    }

    private var badgeBackgroundColor: Color {
        if entry.isVideoFile { return .purple.opacity(0.15) }
        if entry.isImageFile { return .blue.opacity(0.15) }
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "wav", "aif", "aiff", "mp3", "m4a": return .pink.opacity(0.15)
        case "prproj", "aep", "drp": return .orange.opacity(0.15)
        case "pdf": return .red.opacity(0.15)
        default: return Color.primary.opacity(0.08)
        }
    }

    private var badgeTextColor: Color {
        if entry.isVideoFile { return .purple }
        if entry.isImageFile { return .blue }
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "wav", "aif", "aiff", "mp3", "m4a": return .pink
        case "prproj", "aep", "drp": return .orange
        case "pdf": return .red
        default: return .secondary
        }
    }
}
