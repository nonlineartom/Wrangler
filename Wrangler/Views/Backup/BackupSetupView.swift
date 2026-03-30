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
                .padding(.top, 40)

                // Directory selectors
                VStack(spacing: 12) {
                    DirectoryPickerView(
                        label: "Source",
                        icon: "externaldrive.fill",
                        selectedURL: $session.sourceURL
                    )

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)

                    DirectoryPickerView(
                        label: "Destination",
                        icon: "server.rack",
                        selectedURL: $session.destinationURL
                    )
                }
                .padding(.horizontal, 60)

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

                Spacer()
            }
            .padding()
        }
    }
}
