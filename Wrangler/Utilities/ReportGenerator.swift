import Foundation

enum ReportGenerator {
    static func generateTextReport(from report: SyncReport) -> String {
        var lines: [String] = []

        lines.append(String(repeating: "=", count: 60))
        lines.append(" Wrangler Sync Report")
        lines.append(" Generated: \(DateFormatting.reportString(from: report.timestamp))")
        lines.append(String(repeating: "=", count: 60))
        lines.append("")
        lines.append("Source:      \(report.sourceRoot.path)")
        lines.append("Destination: \(report.destinationRoot.path)")
        lines.append("")
        lines.append("Duration:    \(ByteCountFormatting.durationString(from: report.duration))")
        lines.append("Throughput:  \(ByteCountFormatting.throughputString(bytesPerSecond: report.averageThroughput)) avg")
        lines.append("Transferred: \(ByteCountFormatting.string(fromByteCount: report.totalBytesTransferred))")
        lines.append("Verified:    \(report.allVerified ? "All checksums match" : "SOME CHECKSUMS FAILED")")
        lines.append("")

        // Summary
        lines.append("--- Summary ---")
        lines.append("Copied:   \(report.filesCopied.count) files")
        lines.append("Updated:  \(report.filesUpdated.count) files")
        lines.append("Skipped:  \(report.filesSkipped.count) files (already identical)")
        lines.append("Deleted:  \(report.filesDeleted.count) files (orphaned)")
        lines.append("Errors:   \(report.errors.count)")
        lines.append("")

        // Copied files
        if !report.filesCopied.isEmpty {
            lines.append("--- Copied Files ---")
            for file in report.filesCopied {
                lines.append(formatFileRecord(file, prefix: "+"))
            }
            lines.append("")
        }

        // Updated files
        if !report.filesUpdated.isEmpty {
            lines.append("--- Updated Files ---")
            for file in report.filesUpdated {
                lines.append(formatFileRecord(file, prefix: "~"))
            }
            lines.append("")
        }

        // Deleted files
        if !report.filesDeleted.isEmpty {
            lines.append("--- Deleted Orphans ---")
            for file in report.filesDeleted {
                lines.append(formatFileRecord(file, prefix: "x"))
            }
            lines.append("")
        }

        // Errors
        if !report.errors.isEmpty {
            lines.append("--- Errors ---")
            for error in report.errors {
                lines.append("  ! \(error.relativePath): \(error.message)")
            }
            lines.append("")
        }

        lines.append(String(repeating: "=", count: 60))

        return lines.joined(separator: "\n")
    }

    static func generateMarkdownReport(from report: SyncReport) -> String {
        var lines: [String] = []

        lines.append("# Wrangler Sync Report")
        lines.append("")
        lines.append("**Generated:** \(DateFormatting.reportString(from: report.timestamp))")
        lines.append("")
        lines.append("| | |")
        lines.append("|---|---|")
        lines.append("| **Source** | `\(report.sourceRoot.path)` |")
        lines.append("| **Destination** | `\(report.destinationRoot.path)` |")
        lines.append("| **Duration** | \(ByteCountFormatting.durationString(from: report.duration)) |")
        lines.append("| **Throughput** | \(ByteCountFormatting.throughputString(bytesPerSecond: report.averageThroughput)) avg |")
        lines.append("| **Transferred** | \(ByteCountFormatting.string(fromByteCount: report.totalBytesTransferred)) |")
        lines.append("| **Verified** | \(report.allVerified ? "All checksums match" : "**FAILURES**") |")
        lines.append("")

        lines.append("## Summary")
        lines.append("- Copied: \(report.filesCopied.count) files")
        lines.append("- Updated: \(report.filesUpdated.count) files")
        lines.append("- Skipped: \(report.filesSkipped.count) files")
        lines.append("- Errors: \(report.errors.count)")
        lines.append("")

        if !report.filesCopied.isEmpty {
            lines.append("## Copied Files")
            lines.append("| File | Size | Date | Owner | SHA256 |")
            lines.append("|------|------|------|-------|--------|")
            for file in report.filesCopied {
                let checksum = file.checksum.map { String($0.prefix(12)) + "..." } ?? "-"
                lines.append("| `\(file.relativePath)` | \(ByteCountFormatting.string(fromByteCount: file.fileSize)) | \(DateFormatting.shortString(from: file.modificationDate)) | \(file.ownerName ?? "-") | `\(checksum)` |")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func formatFileRecord(_ file: SyncedFileRecord, prefix: String) -> String {
        let size = ByteCountFormatting.string(fromByteCount: file.fileSize).padding(toLength: 10, withPad: " ", startingAt: 0)
        let date = DateFormatting.shortString(from: file.modificationDate)
        let owner = file.ownerName ?? "-"
        let checksum = file.checksum.map { "SHA256:\(String($0.prefix(8)))..." } ?? ""

        return "  \(prefix) \(file.relativePath)  \(size)  \(date)  owner:\(owner)  \(checksum)"
    }
}
