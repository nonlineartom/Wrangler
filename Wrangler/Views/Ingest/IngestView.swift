import SwiftUI

struct IngestView: View {
    @Bindable var session: IngestSession

    var body: some View {
        VStack(spacing: 0) {
            switch session.phase {
            case .browsing:
                dualPaneBrowser
            case .copying:
                IngestProgressView(session: session)
            case .complete:
                ingestCompleteView
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if session.phase == .browsing {
                    Button {
                        Task { await session.copySelectedFiles() }
                    } label: {
                        Label("Copy", systemImage: "arrow.right.circle.fill")
                    }
                    .disabled(!session.canCopy)
                    .buttonStyle(.borderedProminent)

                    Text("\(session.selectedFiles.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var dualPaneBrowser: some View {
        HSplitView {
            FileBrowserPane(
                model: session.sourceModel,
                label: "Source",
                selectedFiles: $session.selectedFiles,
                allowSelection: true,
                thumbnails: session.thumbnails,
                onNavigate: { url in
                    Task {
                        await session.loadThumbnails(for: session.sourceModel.entries, baseURL: url)
                    }
                }
            )
            .frame(minWidth: 400)

            FileBrowserPane(
                model: session.destModel,
                label: "Destination",
                selectedFiles: .constant([]),
                allowSelection: false,
                thumbnails: [:],
                onNavigate: nil
            )
            .frame(minWidth: 400)
        }
    }

    private var ingestCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: session.errors.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(session.errors.isEmpty ? .green : .orange)

            Text(session.errors.isEmpty ? "Copy Complete" : "Copy Completed with Errors")
                .font(.title)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("\(session.completedFiles.count) files copied")
                    .font(.title3)

                if session.completedFiles.allSatisfy(\.verified) {
                    Label("All checksums verified", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                }

                if !session.errors.isEmpty {
                    Text("\(session.errors.count) errors")
                        .foregroundStyle(.red)
                }
            }

            Button("New Transfer") {
                session.reset()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.background)
    }
}
