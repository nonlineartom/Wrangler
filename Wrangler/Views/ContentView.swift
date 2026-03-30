import SwiftUI

struct ContentView: View {
    @State private var selectedMode: AppMode = .backup
    @State private var backupSession = BackupSession()
    @State private var ingestSession = IngestSession()

    enum AppMode: String, CaseIterable {
        case backup = "Backup"
        case ingest = "Ingest"

        var icon: String {
            switch self {
            case .backup: "arrow.triangle.2.circlepath"
            case .ingest: "arrow.right.doc.on.clipboard"
            }
        }

        var description: String {
            switch self {
            case .backup: "Sync & verify directories"
            case .ingest: "Copy between volumes"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedMode) {
            Tab(AppMode.backup.rawValue, systemImage: AppMode.backup.icon, value: .backup) {
                backupModeView
            }

            Tab(AppMode.ingest.rawValue, systemImage: AppMode.ingest.icon, value: .ingest) {
                ingestModeView
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .frame(minWidth: 1200, minHeight: 700)
    }

    @ViewBuilder
    private var backupModeView: some View {
        switch backupSession.phase {
        case .setup:
            BackupSetupView(session: backupSession)

        case .scanning:
            scanningView

        case .diffReview:
            DiffView(session: backupSession)

        case .syncing:
            BackupProgressView(session: backupSession)

        case .dashboard:
            if let report = backupSession.syncReport {
                BackupDashboardView(session: backupSession)
                    .navigationDestination(for: String.self) { value in
                        if value == "report" {
                            ReportView(report: report)
                        }
                    }
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing Differences...")
                .font(.title2)
                .fontWeight(.semibold)

            if let progress = backupSession.scanProgress {
                VStack(spacing: 4) {
                    Text(progress.phase)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(progress.filesScanned) files scanned")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()

                    if !progress.currentPath.isEmpty {
                        Text(progress.currentPath)
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 400)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    @ViewBuilder
    private var ingestModeView: some View {
        IngestView(session: ingestSession)
    }
}
