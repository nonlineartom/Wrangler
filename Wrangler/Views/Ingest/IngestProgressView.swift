import SwiftUI

struct IngestProgressView: View {
    @Bindable var session: IngestSession
    @State private var showCancelConfirm = false

    var body: some View {
        VStack(spacing: 20) {
            // Overall progress
            VStack(spacing: 8) {
                HStack {
                    Text("Copying Files")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    ThroughputGaugeView(
                        bytesPerSecond: session.copyProgress.throughputBytesPerSecond,
                        eta: session.copyProgress.estimatedTimeRemaining
                    )
                }

                ProgressView(value: session.copyProgress.overallProgress)
                    .progressViewStyle(.linear)

                HStack {
                    Text("\(session.copyProgress.completedFiles) of \(session.copyProgress.totalFiles) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(ByteCountFormatting.string(fromByteCount: session.copyProgress.transferredBytes)) / \(ByteCountFormatting.string(fromByteCount: session.copyProgress.totalBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding()

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

            // Completed files list
            if !session.copyProgress.completedFileNames.isEmpty {
                GroupBox("Completed") {
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
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding(.horizontal)
            }

            Spacer()

            // Cancel button
            Button("Cancel") {
                showCancelConfirm = true
            }
            .buttonStyle(.bordered)
            .padding(.bottom)
            .confirmationDialog("Cancel Transfer?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                Button("Cancel Transfer", role: .destructive) {
                    Task { await session.cancelCopy() }
                }
                Button("Continue", role: .cancel) { }
            } message: {
                Text("The partial files written so far will be cleaned up.")
            }
        }
        .background(.background)
    }
}
