import SwiftUI

struct DirectoryPickerView: View {
    let label: String
    let icon: String
    @Binding var selectedURL: URL?
    var volumeInfo: VolumeInfo?

    @State private var isTargeted = false
    @State private var connectionInfo: DriveConnectionInfo?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text(label)
                        .font(.headline)

                    Spacer()

                    Button("Browse...") {
                        selectDirectory()
                    }
                }

                if let url = selectedURL {
                    HStack(spacing: 8) {
                        Image(nsImage: VolumeDetector.volumeIcon(for: url))
                            .resizable()
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.path)
                                .font(.subheadline.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)

                            HStack(spacing: 8) {
                                if let vi = volumeInfo ?? VolumeDetector.volumeInfo(for: url) {
                                    Label(vi.typeLabel, systemImage: vi.typeIcon)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text("\(ByteCountFormatting.string(fromByteCount: vi.availableCapacity)) free")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let conn = connectionInfo {
                                    ConnectionBadge(info: conn)
                                }
                            }
                        }

                        Spacer()

                        Button {
                            selectedURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    .task(id: url) {
                        connectionInfo = DriveConnectionDetector.detect(for: url)
                    }
                } else {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "folder.badge.plus")
                                .font(.title)
                                .foregroundStyle(.tertiary)
                            Text("Drop a folder here or click Browse")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                                style: StrokeStyle(lineWidth: 2, dash: [6])
                            )
                    )
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    DispatchQueue.main.async {
                        self.selectedURL = url
                    }
                }
            }
            return true
        }
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select \(label.lowercased()) directory"

        if panel.runModal() == .OK {
            selectedURL = panel.url
        }
    }
}
