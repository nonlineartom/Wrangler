import SwiftUI

enum DiffStatus: String, CaseIterable, Sendable {
    case identical
    case modified
    case newOnSource
    case orphaned

    var label: String {
        switch self {
        case .identical: "Identical"
        case .modified: "Modified"
        case .newOnSource: "New"
        case .orphaned: "Orphaned"
        }
    }

    var color: Color {
        switch self {
        case .identical: .green
        case .modified: .orange
        case .newOnSource: .blue
        case .orphaned: .red
        }
    }

    var iconName: String {
        switch self {
        case .identical: "checkmark.circle.fill"
        case .modified: "arrow.triangle.2.circlepath.circle.fill"
        case .newOnSource: "plus.circle.fill"
        case .orphaned: "xmark.circle.fill"
        }
    }
}

struct DiffEntry: Identifiable, Sendable {
    let id: String
    let relativePath: String
    let fileName: String
    let isDirectory: Bool
    let status: DiffStatus
    let sourceEntry: FileEntry?
    let destinationEntry: FileEntry?
    var children: [DiffEntry]?

    init(
        relativePath: String,
        fileName: String,
        isDirectory: Bool,
        status: DiffStatus,
        sourceEntry: FileEntry? = nil,
        destinationEntry: FileEntry? = nil,
        children: [DiffEntry]? = nil
    ) {
        self.id = relativePath
        self.relativePath = relativePath
        self.fileName = fileName
        self.isDirectory = isDirectory
        self.status = status
        self.sourceEntry = sourceEntry
        self.destinationEntry = destinationEntry
        self.children = children
    }

    var displaySize: String {
        let size = sourceEntry?.fileSize ?? destinationEntry?.fileSize ?? 0
        return ByteCountFormatting.string(fromByteCount: size)
    }

    var displayDate: Date? {
        sourceEntry?.modificationDate ?? destinationEntry?.modificationDate
    }
}
