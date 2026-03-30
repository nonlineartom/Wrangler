import SwiftUI

struct BackupProgressView: View {
    @Bindable var session: BackupSession

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Syncing Files")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(session.copyProgress.completedFiles) of \(session.copyProgress.totalFiles) files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ThroughputGaugeView(
                    bytesPerSecond: session.copyProgress.throughputBytesPerSecond,
                    eta: session.copyProgress.estimatedTimeRemaining
                )
            }
            .padding(.horizontal)

            // Overall progress
            VStack(spacing: 6) {
                ProgressView(value: session.copyProgress.overallProgress)
                    .progressViewStyle(.linear)

                HStack {
                    Text(ByteCountFormatting.string(fromByteCount: session.copyProgress.transferredBytes))
                        .font(.caption)
                        .monospacedDigit()

                    Spacer()

                    Text(ByteCountFormatting.string(fromByteCount: session.copyProgress.totalBytes))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            Divider()

            // Current file block progress
            if !session.copyProgress.currentFileName.isEmpty {
                BlockProgressView(
                    blocksTotal: session.copyProgress.currentFileBlocksTotal,
                    blocksCompleted: session.copyProgress.currentFileBlocksCompleted,
                    fileName: session.copyProgress.currentFileName,
                    fileSize: session.copyProgress.currentFileSize,
                    bytesTransferred: session.copyProgress.currentFileBytesTransferred,
                    throughputBPS: session.copyProgress.throughputBytesPerSecond
                )
                .padding(.horizontal)
            }

            // Completed files
            GroupBox {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(session.copyProgress.completedFileNames) { file in
                                HStack(spacing: 6) {
                                    Image(systemName: file.verified ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                        .foregroundStyle(file.verified ? .green : .orange)
                                        .font(.caption)

                                    Text(file.relativePath)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Text(ByteCountFormatting.string(fromByteCount: file.fileSize))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .id(file.id)
                            }
                        }
                    }
                    .onChange(of: session.copyProgress.completedFileNames.count) {
                        if let last = session.copyProgress.completedFileNames.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            } label: {
                Label("Completed Files", systemImage: "checkmark.circle")
            }
            .padding(.horizontal)

            Spacer()

            // Cancel button
            Button("Cancel Sync") {
                Task { await session.cancelSync() }
            }
            .buttonStyle(.bordered)
            .padding(.bottom)
        }
        .padding(.top)
        .background(.background)
    }
}
