import SwiftUI

struct BackupSetupView: View {
    @Bindable var session: BackupSession

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    Text("Backup Sync")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Compare and synchronize directories with checksum verification")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Directory selectors
                VStack(spacing: 12) {
                    DirectoryPickerView(
                        label: "Source",
                        icon: "externaldrive.fill",
                        selectedURL: $session.sourceURL
                    )
                    .onChange(of: session.sourceURL) {
                        Task { await session.loadSourceEntries() }
                    }

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)

                    DirectoryPickerView(
                        label: "Destination",
                        icon: "server.rack",
                        selectedURL: $session.destinationURL
                    )
                    .onChange(of: session.destinationURL) {
                        Task { await session.loadDestEntries() }
                    }
                }
                .padding(.horizontal, 40)

                // Treemap — shown as soon as at least one directory is selected
                if !session.sourceEntries.isEmpty || !session.destEntries.isEmpty {
                    DualTreemapPanel(
                        sourceEntries: session.sourceEntries,
                        destEntries: session.destEntries,
                        sourceTitle: session.sourceURL?.lastPathComponent ?? "Source",
                        destTitle: session.destinationURL?.lastPathComponent ?? "Destination"
                    )
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Start button
                Button {
                    Task { await session.startScan() }
                } label: {
                    Label("Analyze Differences", systemImage: "magnifyingglass")
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!session.canStartScan)
                .padding(.bottom, 32)
            }
            .padding()
            .animation(.default, value: session.sourceEntries.count)
            .animation(.default, value: session.destEntries.count)
        }
    }
}
