import SwiftUI

struct ReportView: View {
    let report: SyncReport
    @State private var reportText: String = ""
    @State private var reportFormat: ReportFormat = .text

    enum ReportFormat: String, CaseIterable {
        case text = "Plain Text"
        case markdown = "Markdown"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("Format", selection: $reportFormat) {
                    ForEach(ReportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    exportReport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Report content
            ScrollView {
                Text(reportText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .onAppear { generateReport() }
        .onChange(of: reportFormat) { generateReport() }
        .navigationTitle("Sync Report")
    }

    private func generateReport() {
        switch reportFormat {
        case .text:
            reportText = ReportGenerator.generateTextReport(from: report)
        case .markdown:
            reportText = ReportGenerator.generateMarkdownReport(from: report)
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reportText, forType: .string)
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "wrangler-report-\(DateFormatting.shortString(from: report.timestamp))"

        switch reportFormat {
        case .text:
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue += ".txt"
        case .markdown:
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue += ".md"
        }

        if panel.runModal() == .OK, let url = panel.url {
            try? reportText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
