import SwiftUI

// MARK: - Treemap Data Model

struct TreemapNode: Identifiable {
    let id: String
    let name: String
    let relativePath: String
    let size: Int64
    let isDirectory: Bool
    let children: [TreemapNode]
    var rect: CGRect = .zero

    var totalSize: Int64 {
        isDirectory ? children.reduce(0) { $0 + $1.totalSize } : size
    }

    static func build(from entries: [FileEntry], root: URL) -> [TreemapNode] {
        // Group by top-level path component
        var topLevel: [String: [FileEntry]] = [:]
        var topLevelFiles: [FileEntry] = []

        for entry in entries {
            let components = entry.relativePath.split(separator: "/")
            if components.count == 1 {
                topLevelFiles.append(entry)
            } else {
                let top = String(components[0])
                topLevel[top, default: []].append(entry)
            }
        }

        var nodes: [TreemapNode] = []

        // Top-level files
        for entry in topLevelFiles where !entry.isDirectory {
            nodes.append(TreemapNode(
                id: entry.relativePath,
                name: entry.fileName,
                relativePath: entry.relativePath,
                size: entry.fileSize,
                isDirectory: false,
                children: []
            ))
        }

        // Top-level directories
        for (dirName, children) in topLevel {
            let childNodes = children.compactMap { entry -> TreemapNode? in
                guard !entry.isDirectory else { return nil }
                return TreemapNode(
                    id: entry.relativePath,
                    name: entry.fileName,
                    relativePath: entry.relativePath,
                    size: entry.fileSize,
                    isDirectory: false,
                    children: []
                )
            }
            if childNodes.isEmpty { continue }
            nodes.append(TreemapNode(
                id: dirName,
                name: dirName,
                relativePath: dirName,
                size: 0,
                isDirectory: true,
                children: childNodes
            ))
        }

        return nodes.sorted { $0.totalSize > $1.totalSize }
    }
}

// MARK: - Squarified Treemap Layout

enum TreemapLayout {
    static func layout(nodes: [TreemapNode], in rect: CGRect) -> [TreemapNode] {
        var result = nodes
        squarify(items: &result, rect: rect)
        return result
    }

    private static func squarify(items: inout [TreemapNode], rect: CGRect) {
        guard !items.isEmpty, rect.width > 1, rect.height > 1 else { return }

        let total = items.reduce(Int64(0)) { $0 + $1.totalSize }
        guard total > 0 else { return }

        // Try to lay out items in rows that minimize aspect ratio
        var row: [Int] = []  // indices
        var remaining = Array(items.indices)
        var currentRect = rect

        while !remaining.isEmpty {
            let idx = remaining.removeFirst()
            row.append(idx)

            // Check if adding next item improves worst aspect ratio
            if !remaining.isEmpty {
                let currentWorst = worstRatio(row: row.map { items[$0] }, rect: currentRect, total: total)
                let nextRow = row + [remaining[0]]
                let nextWorst = worstRatio(row: nextRow.map { items[$0] }, rect: currentRect, total: total)

                if nextWorst > currentWorst {
                    // Lay out current row and start fresh
                    currentRect = layoutRow(indices: row, items: &items, rect: currentRect, total: total)
                    row = []
                }
            }
        }

        if !row.isEmpty {
            layoutRow(indices: row, items: &items, rect: currentRect, total: total)
        }
    }

    @discardableResult
    private static func layoutRow(
        indices: [Int],
        items: inout [TreemapNode],
        rect: CGRect,
        total: Int64
    ) -> CGRect {
        let rowTotal = indices.reduce(Int64(0)) { $0 + items[$1].totalSize }
        guard rowTotal > 0, total > 0 else { return rect }

        let fraction = Double(rowTotal) / Double(total)
        let isWide = rect.width >= rect.height

        var offset: CGFloat = 0
        let rowSize = isWide ? rect.height * CGFloat(fraction) : rect.width * CGFloat(fraction)

        for idx in indices {
            let itemFraction = Double(items[idx].totalSize) / Double(rowTotal)
            let itemLength = (isWide ? rect.width : rect.height) * CGFloat(itemFraction)

            let itemRect: CGRect
            if isWide {
                itemRect = CGRect(
                    x: rect.minX + offset,
                    y: rect.minY,
                    width: itemLength,
                    height: rowSize
                )
            } else {
                itemRect = CGRect(
                    x: rect.minX,
                    y: rect.minY + offset,
                    width: rowSize,
                    height: itemLength
                )
            }

            items[idx].rect = itemRect

            // Recurse into directories
            if items[idx].isDirectory && !items[idx].children.isEmpty {
                let padding: CGFloat = 2
                let innerRect = itemRect.insetBy(dx: padding, dy: padding)
                var children = items[idx].children.sorted { $0.totalSize > $1.totalSize }
                squarify(items: &children, rect: innerRect)
                items[idx] = TreemapNode(
                    id: items[idx].id,
                    name: items[idx].name,
                    relativePath: items[idx].relativePath,
                    size: items[idx].size,
                    isDirectory: true,
                    children: children,
                    rect: itemRect
                )
            }

            offset += itemLength
        }

        // Return the remaining rect
        if isWide {
            return CGRect(x: rect.minX, y: rect.minY + rowSize, width: rect.width, height: rect.height - rowSize)
        } else {
            return CGRect(x: rect.minX + rowSize, y: rect.minY, width: rect.width - rowSize, height: rect.height)
        }
    }

    private static func worstRatio(row: [TreemapNode], rect: CGRect, total: Int64) -> Double {
        guard !row.isEmpty else { return .infinity }
        let rowTotal = row.reduce(Int64(0)) { $0 + $1.totalSize }
        guard rowTotal > 0, total > 0 else { return .infinity }

        let isWide = rect.width >= rect.height
        let availableLength = isWide ? rect.width : rect.height
        let fraction = Double(rowTotal) / Double(total)
        let rowThickness = (isWide ? rect.height : rect.width) * CGFloat(fraction)

        var worst: Double = 0
        for item in row {
            let itemFraction = Double(item.totalSize) / Double(rowTotal)
            let itemLength = availableLength * CGFloat(itemFraction)
            let w = min(itemLength, rowThickness)
            let h = max(itemLength, rowThickness)
            let ratio = h / max(w, 0.001)
            worst = max(worst, Double(ratio))
        }
        return worst
    }
}

// MARK: - Color Mapping

extension TreemapNode {
    var displayColor: Color {
        let ext = (name as NSString).pathExtension.lowercased()
        if FileEntry.videoExtensions.contains(ext) { return .purple }
        if FileEntry.imageExtensions.contains(ext) { return .blue }
        switch ext {
        case "prproj", "aep", "resolve", "drp": return .orange
        case "wav", "aif", "aiff", "mp3", "m4a": return .pink
        case "xml", "json", "csv": return .yellow
        case "pdf", "doc", "docx": return .red
        default: return isDirectory ? .clear : Color(hue: Double(name.hashValue & 0xFF) / 255.0, saturation: 0.5, brightness: 0.7)
        }
    }
}

// MARK: - Main View

struct TreemapView: View {
    let entries: [FileEntry]
    let title: String
    var baseURL: URL?           // used for Quick Look and Reveal in Finder
    var onSelect: ((FileEntry) -> Void)?

    @State private var nodes: [TreemapNode] = []
    @State private var hoveredPath: String?
    @State private var selectedEntry: FileEntry?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar — shows hovered/selected path
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let entry = selectedEntry ?? hoveredEntry {
                    Text(entry.relativePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)

                    if !entry.isDirectory {
                        Text(ByteCountFormatting.string(fromByteCount: entry.fileSize))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }

                if selectedEntry != nil {
                    // Space = Quick Look hint
                    Text("␣ preview")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 3))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial)

            Divider()

            // Treemap canvas
            GeometryReader { geo in
                ZStack {
                    Rectangle().fill(Color(.windowBackgroundColor))

                    Canvas { ctx, size in
                        drawNodes(nodes, in: ctx, canvasSize: size)
                    }

                    // Interaction overlay
                    Color.clear
                        .contentShape(Rectangle())
                        .focused($isFocused)
                        .focusable()
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                hoveredPath = findNode(at: location, in: nodes)?.relativePath
                            case .ended:
                                hoveredPath = nil
                            }
                        }
                        .onTapGesture { location in
                            isFocused = true
                            if let node = findNode(at: location, in: nodes),
                               let entry = entries.first(where: { $0.relativePath == node.relativePath }) {
                                selectedEntry = entry
                                onSelect?(entry)
                            } else {
                                selectedEntry = nil
                            }
                        }
                        // Space bar → Quick Look
                        .onKeyPress(.space) {
                            guard let entry = selectedEntry,
                                  let url = fullURL(for: entry) else { return .ignored }
                            QuickLookHelper.preview(url: url)
                            return .handled
                        }
                        // Context menu: Reveal in Finder + Quick Look
                        .contextMenu {
                            let target = hoveredEntry ?? selectedEntry
                            if let entry = target, let url = fullURL(for: entry) {
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                } label: {
                                    Label("Reveal in Finder", systemImage: "folder")
                                }

                                Button {
                                    QuickLookHelper.preview(url: url)
                                } label: {
                                    Label("Quick Look", systemImage: "eye")
                                }

                                Divider()

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(entry.relativePath, forType: .string)
                                } label: {
                                    Label("Copy Relative Path", systemImage: "doc.on.clipboard")
                                }

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url.path, forType: .string)
                                } label: {
                                    Label("Copy Full Path", systemImage: "doc.on.doc")
                                }
                            }
                        }
                }
                .onChange(of: entries.count) { rebuildLayout(in: geo.size) }
                .onAppear { rebuildLayout(in: geo.size) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }

    private var hoveredEntry: FileEntry? {
        guard let path = hoveredPath else { return nil }
        return entries.first { $0.relativePath == path }
    }

    private func fullURL(for entry: FileEntry) -> URL? {
        baseURL?.appendingPathComponent(entry.relativePath)
    }

    private func rebuildLayout(in size: CGSize) {
        guard size.width > 10, size.height > 10 else { return }
        var raw = TreemapNode.build(from: entries, root: URL(fileURLWithPath: "/"))
        raw = TreemapLayout.layout(nodes: raw, in: CGRect(origin: .zero, size: size))
        nodes = raw
    }

    private func drawNodes(_ nodes: [TreemapNode], in ctx: GraphicsContext, canvasSize: CGSize) {
        for node in nodes {
            guard node.rect.width > 2, node.rect.height > 2 else { continue }

            if node.isDirectory {
                // Directory: draw header bar + recurse
                let headerH: CGFloat = min(16, node.rect.height * 0.2)
                let headerRect = CGRect(x: node.rect.minX, y: node.rect.minY, width: node.rect.width, height: headerH)

                ctx.fill(Path(headerRect), with: .color(.gray.opacity(0.25)))

                // Text labels are shown in the hover tooltip (header bar above canvas)

                // Recurse into children
                drawNodes(node.children, in: ctx, canvasSize: canvasSize)

                // Directory border
                ctx.stroke(
                    Path(node.rect),
                    with: .color(.white.opacity(0.15)),
                    lineWidth: 1
                )

            } else {
                // File: fill with colour, stroke border
                let isHovered   = hoveredPath    == node.relativePath
                let isSelected  = selectedEntry?.relativePath == node.relativePath
                let color = node.displayColor
                let fillColor = (isHovered || isSelected) ? color.opacity(0.95) : color.opacity(0.75)

                ctx.fill(Path(node.rect), with: .color(fillColor))

                if isSelected {
                    // Bold white selection border
                    ctx.stroke(Path(node.rect), with: .color(.white.opacity(0.9)), lineWidth: 2)
                } else {
                    ctx.stroke(Path(node.rect), with: .color(.black.opacity(0.3)), lineWidth: 0.5)
                }
            }
        }
    }

    private func findNode(at point: CGPoint, in nodes: [TreemapNode]) -> TreemapNode? {
        for node in nodes.reversed() {
            guard node.rect.contains(point) else { continue }
            if node.isDirectory {
                if let child = findNode(at: point, in: node.children) {
                    return child
                }
            }
            return node.isDirectory ? nil : node
        }
        return nil
    }
}

// MARK: - Legend

struct TreemapLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legendItem("Video", color: .purple)
            legendItem("Photo", color: .blue)
            legendItem("Project", color: .orange)
            legendItem("Audio", color: .pink)
            legendItem("Document", color: .red)
            legendItem("Other", color: .gray)
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.75))
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Dual Treemap Panel (for setup screen)

struct DualTreemapPanel: View {
    let sourceEntries: [FileEntry]
    let destEntries: [FileEntry]
    let sourceTitle: String
    let destTitle: String
    var sourceBaseURL: URL?
    var destBaseURL: URL?

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TreemapView(
                        entries: sourceEntries,
                        title: sourceTitle,
                        baseURL: sourceBaseURL
                    )
                    .frame(minHeight: 200)

                    if !destEntries.isEmpty {
                        TreemapView(
                            entries: destEntries,
                            title: destTitle,
                            baseURL: destBaseURL
                        )
                        .frame(minHeight: 200)
                    }
                }
                TreemapLegend()
            }
        } label: {
            Label("Directory View", systemImage: "square.grid.3x3.fill")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
