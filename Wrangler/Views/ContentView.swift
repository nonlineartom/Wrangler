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
            case .backup: "arrow.triangle.2.circlepath.circle.fill"
            case .ingest: "arrow.right.doc.on.clipboard.fill"
            }
        }

        var subtitle: String {
            switch self {
            case .backup: "Verify & sync directories"
            case .ingest: "Copy between drives"
            }
        }
    }

    private var isTransferring: Bool {
        backupSession.phase == .syncing ||
        ingestSession.phase == .copying
    }

    var body: some View {
        VStack(spacing: 0) {
            if isTransferring {
                StorageMonitorBar()
                Divider()
            }

            NavigationSplitView {
                sidebarContent
                    .navigationSplitViewColumnWidth(min: 175, ideal: 195, max: 220)
            } detail: {
                Group {
                    switch selectedMode {
                    case .backup: backupModeView
                    case .ingest: IngestView(session: ingestSession)
                    }
                }
                .frame(minWidth: 900, minHeight: 560)
            }
        }
        .frame(minWidth: 1100, minHeight: 764)
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(AppMode.allCases, id: \.self, selection: $selectedMode) { mode in
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(mode.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: mode.icon)
                    .font(.body)
                    .foregroundStyle(.tint)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Wrangler")
    }

    // MARK: - Backup flow

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
                            if value == "report" { ReportView(report: report) }
                        }
                }
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Analyzing Differences…")
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
}
