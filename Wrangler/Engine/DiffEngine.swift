import Foundation

actor DiffEngine {
    struct ScanProgress: Sendable {
        let phase: String
        let filesScanned: Int
        let currentPath: String
    }

    private let checksumEngine = ChecksumEngine()

    func compare(
        source: URL,
        destination: URL,
        progressHandler: (@Sendable (ScanProgress) -> Void)? = nil
    ) async throws -> DiffResult {
        // Phase 1: Structural scan — enumerate both trees
        progressHandler?(ScanProgress(phase: "Scanning source...", filesScanned: 0, currentPath: ""))
        let sourceEntries = try await scanDirectory(root: source, progressHandler: { count, path in
            progressHandler?(ScanProgress(phase: "Scanning source...", filesScanned: count, currentPath: path))
        })

        progressHandler?(ScanProgress(phase: "Scanning destination...", filesScanned: 0, currentPath: ""))
        let destEntries = try await scanDirectory(root: destination, progressHandler: { count, path in
            progressHandler?(ScanProgress(phase: "Scanning destination...", filesScanned: count, currentPath: path))
        })

        // Build lookup dictionaries by relative path
        let sourceMap = Dictionary(uniqueKeysWithValues: sourceEntries.map { ($0.relativePath, $0) })
        let destMap = Dictionary(uniqueKeysWithValues: destEntries.map { ($0.relativePath, $0) })

        let allPaths = Set(sourceMap.keys).union(Set(destMap.keys))
            .sorted()

        // Phase 2 & 3: Compare entries
        var diffEntries: [DiffEntry] = []
        var checksumNeeded: [(path: String, sourceURL: URL, destURL: URL)] = []

        progressHandler?(ScanProgress(phase: "Comparing files...", filesScanned: 0, currentPath: ""))

        for (index, path) in allPaths.enumerated() {
            try Task.checkCancellation()

            let sourceEntry = sourceMap[path]
            let destEntry = destMap[path]

            if let src = sourceEntry, destEntry == nil {
                // New on source
                diffEntries.append(DiffEntry(
                    relativePath: path,
                    fileName: src.fileName,
                    isDirectory: src.isDirectory,
                    status: .newOnSource,
                    sourceEntry: src
                ))
            } else if sourceEntry == nil, let dst = destEntry {
                // Orphaned
                diffEntries.append(DiffEntry(
                    relativePath: path,
                    fileName: dst.fileName,
                    isDirectory: dst.isDirectory,
                    status: .orphaned,
                    destinationEntry: dst
                ))
            } else if let src = sourceEntry, let dst = destEntry {
                if src.isDirectory && dst.isDirectory {
                    // Both directories — will be resolved by children
                    continue
                }

                // Phase 2: Size comparison
                if src.fileSize != dst.fileSize {
                    diffEntries.append(DiffEntry(
                        relativePath: path,
                        fileName: src.fileName,
                        isDirectory: false,
                        status: .modified,
                        sourceEntry: src,
                        destinationEntry: dst
                    ))
                } else {
                    // Same size — needs checksum (Phase 3)
                    checksumNeeded.append((
                        path: path,
                        sourceURL: source.appendingPathComponent(path),
                        destURL: destination.appendingPathComponent(path)
                    ))
                }
            }

            if index % 100 == 0 {
                progressHandler?(ScanProgress(
                    phase: "Comparing files...",
                    filesScanned: index,
                    currentPath: path
                ))
            }
        }

        // Phase 3: Checksum verification for same-size files
        if !checksumNeeded.isEmpty {
            progressHandler?(ScanProgress(
                phase: "Verifying checksums...",
                filesScanned: 0,
                currentPath: "\(checksumNeeded.count) files to verify"
            ))

            for (index, item) in checksumNeeded.enumerated() {
                try Task.checkCancellation()

                progressHandler?(ScanProgress(
                    phase: "Verifying checksums...",
                    filesScanned: index + 1,
                    currentPath: item.path
                ))

                let sourceChecksum = try await checksumEngine.computeChecksum(for: item.sourceURL)
                let destChecksum = try await checksumEngine.computeChecksum(for: item.destURL)

                var src = sourceMap[item.path]!
                var dst = destMap[item.path]!
                src.checksum = sourceChecksum
                dst.checksum = destChecksum

                let status: DiffStatus = (sourceChecksum == destChecksum) ? .identical : .modified

                diffEntries.append(DiffEntry(
                    relativePath: item.path,
                    fileName: src.fileName,
                    isDirectory: false,
                    status: status,
                    sourceEntry: src,
                    destinationEntry: dst
                ))
            }
        }

        // Build summary
        let summary = buildSummary(from: diffEntries)

        // Build tree structure
        let tree = buildTree(from: diffEntries)

        return DiffResult(
            sourceRoot: source,
            destinationRoot: destination,
            entries: diffEntries.sorted { $0.relativePath < $1.relativePath },
            tree: tree,
            summary: summary,
            timestamp: .now
        )
    }

    private func scanDirectory(
        root: URL,
        progressHandler: @Sendable (Int, String) -> Void
    ) async throws -> [FileEntry] {
        let keys: Set<URLResourceKey> = [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isDirectoryKey,
            .nameKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            throw WranglerError.sourceNotAccessible(root)
        }

        var entries: [FileEntry] = []
        var count = 0

        for case let url as URL in enumerator {
            try Task.checkCancellation()

            guard let values = try? url.resourceValues(forKeys: keys) else { continue }

            let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
            let isDir = values.isDirectory ?? false

            let entry = FileEntry(
                relativePath: relativePath,
                fileName: values.name ?? url.lastPathComponent,
                isDirectory: isDir,
                fileSize: Int64(values.fileSize ?? 0),
                modificationDate: values.contentModificationDate ?? .distantPast,
                creationDate: values.creationDate,
                ownerName: FileManager.default.ownerOfItem(atPath: url.path)
            )

            entries.append(entry)
            count += 1

            if count % 50 == 0 {
                progressHandler(count, relativePath)
            }
        }

        return entries
    }

    private func buildSummary(from entries: [DiffEntry]) -> DiffSummary {
        let fileEntries = entries.filter { !$0.isDirectory }
        let identical = fileEntries.filter { $0.status == .identical }
        let modified = fileEntries.filter { $0.status == .modified }
        let newOnSource = fileEntries.filter { $0.status == .newOnSource }
        let orphaned = fileEntries.filter { $0.status == .orphaned }

        let totalSourceSize = fileEntries.compactMap { $0.sourceEntry?.fileSize }.reduce(0, +)
        let totalDestSize = fileEntries.compactMap { $0.destinationEntry?.fileSize }.reduce(0, +)
        let bytesToTransfer = newOnSource.compactMap { $0.sourceEntry?.fileSize }.reduce(0, +)
            + modified.compactMap { $0.sourceEntry?.fileSize }.reduce(0, +)

        return DiffSummary(
            totalFiles: fileEntries.count,
            identicalCount: identical.count,
            modifiedCount: modified.count,
            newOnSourceCount: newOnSource.count,
            orphanedCount: orphaned.count,
            totalSourceSize: totalSourceSize,
            totalDestinationSize: totalDestSize,
            bytesToTransfer: bytesToTransfer
        )
    }

    private func buildTree(from entries: [DiffEntry]) -> [DiffEntry] {
        // Group entries by their parent directory
        var directoryChildren: [String: [DiffEntry]] = [:]
        var topLevel: [DiffEntry] = []

        for entry in entries.sorted(by: { $0.relativePath < $1.relativePath }) {
            let components = entry.relativePath.split(separator: "/")
            if components.count <= 1 {
                topLevel.append(entry)
            } else {
                let parent = components.dropLast().joined(separator: "/")
                directoryChildren[parent, default: []].append(entry)
            }
        }

        func buildNode(path: String, entry: DiffEntry?) -> DiffEntry {
            let children = directoryChildren[path]?.map { child in
                if child.isDirectory {
                    return buildNode(path: child.relativePath, entry: child)
                }
                return child
            }

            if let entry = entry {
                return DiffEntry(
                    relativePath: entry.relativePath,
                    fileName: entry.fileName,
                    isDirectory: entry.isDirectory,
                    status: aggregateStatus(for: children ?? []),
                    sourceEntry: entry.sourceEntry,
                    destinationEntry: entry.destinationEntry,
                    children: children
                )
            }

            let name = (path as NSString).lastPathComponent
            return DiffEntry(
                relativePath: path,
                fileName: name,
                isDirectory: true,
                status: aggregateStatus(for: children ?? []),
                children: children
            )
        }

        return topLevel
    }

    private func aggregateStatus(for children: [DiffEntry]) -> DiffStatus {
        if children.isEmpty { return .identical }
        if children.allSatisfy({ $0.status == .identical }) { return .identical }
        if children.contains(where: { $0.status == .newOnSource || $0.status == .modified }) { return .modified }
        if children.allSatisfy({ $0.status == .orphaned }) { return .orphaned }
        return .modified
    }
}
