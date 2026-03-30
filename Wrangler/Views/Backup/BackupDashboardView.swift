import SwiftUI

struct BackupDashboardView: View {
    @Bindable var session: BackupSession

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // Status indicator
                if let report = session.syncReport {
                    VStack(spacing: 12) {
                        Image(systemName: report.allVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(report.allVerified ? .green : .orange)

                        Text(report.allVerified ? "All Files Verified" : "Sync Completed with Issues")
                            .font(.title)
                            .fontWeight(.bold)

                        if report.allVerified {
                            Text("Every file has been checksum-verified on both source and destination")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        statCard("Files Synced", "\(report.filesCopied.count)", icon: "doc.on.doc.fill", color: .blue)
                        statCard("Total Size", ByteCountFormatting.string(fromByteCount: report.totalBytesTransferred), icon: "externaldrive.fill", color: .purple)
                        statCard("Duration", ByteCountFormatting.durationString(from: report.duration), icon: "clock.fill", color: .orange)
                        statCard("Throughput", ByteCountFormatting.throughputString(bytesPerSecond: report.averageThroughput), icon: "speedometer", color: .green)
                    }
                    .padding(.horizontal, 40)

                    // Errors
                    if !report.errors.isEmpty {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(report.errors) { error in
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text(error.relativePath)
                                            .font(.caption)
                                        Spacer()
                                        Text(error.message)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            Label("Errors (\(report.errors.count))", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 40)
                    }

                    // Action buttons
                    HStack(spacing: 16) {
                        Button {
                            Task { await session.startScan() }
                        } label: {
                            Label("Re-verify All", systemImage: "checkmark.shield")
                        }
                        .buttonStyle(.bordered)

                        NavigationLink(value: "report") {
                            Label("View Report", systemImage: "doc.text")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            session.reset()
                        } label: {
                            Label("New Sync", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(.background)
    }

    private func statCard(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
