import SwiftUI

struct IngestView: View {
    @Bindable var session: IngestSession

    var body: some View {
        switch session.phase {
        case .browsing:
            dualPaneBrowser
        case .copying:
            IngestProgressView(session: session)
        case .complete:
            ingestCompleteView
        }
    }

    // MARK: - Dual-pane browser

    private var dualPaneBrowser: some View {
        HStack(spacing: 0) {
            // Source pane
            FileBrowserPane(
                model: session.sourceModel,
                label: "Source",
                selectedFiles: $session.selectedFiles,
                allowSelection: true,
                thumbnails: session.thumbnails,
                onNavigate: { url in
                    Task { await session.loadThumbnails(for: session.sourceModel.entries, baseURL: url) }
                }
            )
            .frame(maxWidth: .infinity)

            Divider()

            // Centre action column
            centerActionPanel
                .frame(width: 72)

            Divider()

            // Destination pane
            FileBrowserPane(
                model: session.destModel,
                label: "Destination",
                selectedFiles: .constant([]),
                allowSelection: false,
                thumbnails: [:],
                onNavigate: nil
            )
            .frame(maxWidth: .infinity)
        }
        // Keyboard: Escape clears selection
        .focusable()
        .onKeyPress(.escape) {
            session.selectedFiles.removeAll()
            return .handled
        }
        // ⌘A selects all non-directory entries in source
        .onKeyPress("a", phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            let allPaths = session.sourceModel.entries
                .filter { !$0.isDirectory }
                .map(\.relativePath)
            session.selectedFiles = Set(allPaths)
            return .handled
        }
    }

    // MARK: - Centre action panel

    private var centerActionPanel: some View {
        VStack(spacing: 12) {
            Spacer()

            if session.selectedFiles.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("Select files\nto copy")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 8) {
                    // File count badge
                    VStack(spacing: 2) {
                        Text("\(session.selectedFiles.count)")
                            .font(.title2.bold())
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(session.selectedFiles.count == 1 ? "file" : "files")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Copy button — the primary action
                    Button {
                        Task { await session.copySelectedFiles() }
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(session.canCopy ? Color.accentColor : Color.secondary.opacity(0.4))
                            .symbolEffect(.pulse, isActive: session.canCopy)
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canCopy)
                    .help("Copy selected files to destination")

                    // Total size
                    if let size = selectedTotalSize {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            Spacer()

            // Clear selection button (shown when something is selected)
            if !session.selectedFiles.isEmpty {
                Button {
                    session.selectedFiles.removeAll()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear selection (Esc)")
                .padding(.bottom, 12)
            }
        }
        .background(.regularMaterial)
    }

    private var selectedTotalSize: String? {
        let entries = session.sourceModel.entries.filter {
            session.selectedFiles.contains($0.relativePath)
        }
        let total = entries.reduce(Int64(0)) { $0 + $1.fileSize }
        guard total > 0 else { return nil }
        return ByteCountFormatting.string(fromByteCount: total)
    }

    // MARK: - Complete screen

    private var ingestCompleteView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Status icon
            ZStack {
                Circle()
                    .fill(session.errors.isEmpty ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: session.errors.isEmpty
                      ? "checkmark.circle.fill"
                      : "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(session.errors.isEmpty ? .green : .orange)
            }
            .padding(.bottom, 20)

            Text(session.errors.isEmpty ? "Transfer Complete" : "Transfer Completed with Errors")
                .font(.title2)
                .fontWeight(.semibold)

            Text(session.errors.isEmpty
                 ? "\(session.completedFiles.count) file\(session.completedFiles.count == 1 ? "" : "s") copied and verified\(session.skippedFiles.isEmpty ? "" : " · \(session.skippedFiles.count) already existed")"
                 : "\(session.completedFiles.count) files copied · \(session.errors.count) errors")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            // Verification status
            if session.completedFiles.allSatisfy(\.verified) {
                Label("All checksums verified", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.1), in: Capsule())
                    .padding(.top, 8)
            }

            // Skipped files (already existed — not an error)
            if !session.skippedFiles.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.skippedFiles.prefix(5)) { file in
                            Label(file.relativePath, systemImage: "arrow.right.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if session.skippedFiles.count > 5 {
                            Text("+ \(session.skippedFiles.count - 5) more")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                } label: {
                    Label("Already at destination — not overwritten", systemImage: "checkmark.shield")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 400)
                .padding(.top, 16)
            }

            // Error list
            if !session.errors.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.errors.prefix(5)) { err in
                            Label(err.relativePath, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if session.errors.count > 5 {
                            Text("+ \(session.errors.count - 5) more errors")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Label("Errors", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: 400)
                .padding(.top, 16)
            }

            Spacer()

            Button("New Transfer") { session.reset() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(.background)
    }
}
