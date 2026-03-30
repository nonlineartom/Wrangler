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
    }

    var body: some View {
        VStack(spacing: 0) {
            StorageMonitorBar()

            Divider()

            NavigationSplitView {
                List(AppMode.allCases, id: \.self, selection: $selectedMode) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
            } detail: {
                Group {
                    switch selectedMode {
                    case .backup:
                        backupModeView
                    case .ingest:
                        ingestModeView
                    }
                }
                .frame(minWidth: 900, minHeight: 600)
            }
        }
        .frame(minWidth: 1100, minHeight: 764)
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
                NavigationStack {
                    BackupDashboardView(session: backupSession)
                        .navigationDestination(for: String.self) { value in
                            if value == "report" {
                                ReportView(report: report)
                            }
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
