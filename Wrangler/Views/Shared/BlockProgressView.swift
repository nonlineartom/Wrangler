import SwiftUI

struct BlockProgressView: View {
    let blocksTotal: Int
    let blocksCompleted: Int
    let fileName: String
    let fileSize: Int64
    let bytesTransferred: Int64
    let throughputBPS: Double

    private let blockSize: CGFloat = 3
    private let blockSpacing: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // File info header
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)

                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text("\(ByteCountFormatting.string(fromByteCount: bytesTransferred)) / \(ByteCountFormatting.string(fromByteCount: fileSize))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Block grid
            if blocksTotal > 0 {
                BlockGridCanvas(
                    blocksTotal: blocksTotal,
                    blocksCompleted: blocksCompleted
                )
                .frame(height: blockGridHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Stats row
            HStack {
                Label(
                    "\(Int(progressPercent * 100))%",
                    systemImage: "percent"
                )
                .font(.caption)
                .monospacedDigit()

                Spacer()

                Label(
                    ByteCountFormatting.throughputString(bytesPerSecond: throughputBPS),
                    systemImage: "speedometer"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Label(
                    "\(blocksCompleted) / \(blocksTotal) blocks",
                    systemImage: "square.grid.3x3.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var progressPercent: Double {
        guard fileSize > 0 else { return 0 }
        return Double(bytesTransferred) / Double(fileSize)
    }

    private var blockGridHeight: CGFloat {
        let totalSize = blockSize + blockSpacing
        let maxWidth: CGFloat = 600
        let blocksPerRow = max(1, Int(maxWidth / totalSize))
        let rows = max(1, (blocksTotal + blocksPerRow - 1) / blocksPerRow)
        return CGFloat(min(rows, 80)) * totalSize
    }
}

struct BlockGridCanvas: View {
    let blocksTotal: Int
    let blocksCompleted: Int

    var body: some View {
        Canvas { context, size in
            let blockSize: CGFloat = 3
            let spacing: CGFloat = 1
            let totalSize = blockSize + spacing
            let blocksPerRow = max(1, Int(size.width / totalSize))

            for i in 0..<blocksTotal {
                let row = i / blocksPerRow
                let col = i % blocksPerRow

                let x = CGFloat(col) * totalSize
                let y = CGFloat(row) * totalSize

                guard y < size.height else { break }

                let rect = CGRect(x: x, y: y, width: blockSize, height: blockSize)

                let color: Color
                if i < blocksCompleted {
                    color = .green
                } else if i == blocksCompleted {
                    color = .accentColor
                } else {
                    color = Color(.separatorColor)
                }

                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}
