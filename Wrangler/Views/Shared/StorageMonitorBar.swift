import SwiftUI

// MARK: - Storage Monitor Bar

/// Compact bar showing real-time disk read/write throughput graph and SSD temperature.
struct StorageMonitorBar: View {
    @State private var monitor = StorageMonitor.shared

    var body: some View {
        HStack(spacing: 0) {
            // Graph
            ThroughputGraph(monitor: monitor)
                .frame(maxWidth: .infinity)

            Divider()

            // Stats panel
            statsPanel
                .frame(width: 180)
                .padding(.horizontal, 12)
        }
        .frame(height: 64)
        .background(.ultraThinMaterial)
    }

    private var statsPanel: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(.blue).frame(width: 6, height: 6)
                Text("R  \(formatRate(monitor.current.readBytesPerSec))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
            }
            HStack(spacing: 6) {
                Circle().fill(.orange).frame(width: 6, height: 6)
                Text("W  \(formatRate(monitor.current.writeBytesPerSec))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
            }
            if let temp = monitor.current.temperatureCelsius {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.caption2)
                        .foregroundStyle(tempColor(temp))
                    Text(String(format: "%.0f°C", temp))
                        .font(.caption.monospaced())
                        .foregroundStyle(tempColor(temp))
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("—")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func formatRate(_ bps: Double) -> String {
        if bps >= 1_073_741_824 { return String(format: "%5.1f GB/s", bps / 1_073_741_824) }
        if bps >=     1_048_576 { return String(format: "%5.1f MB/s", bps / 1_048_576) }
        if bps >=          1024 { return String(format: "%5.1f KB/s", bps / 1024) }
        return String(format: "%5.0f  B/s", bps)
    }

    private func tempColor(_ celsius: Double) -> Color {
        if celsius >= 75 { return .red }
        if celsius >= 60 { return .orange }
        return .green
    }
}

// MARK: - Throughput Graph

private struct ThroughputGraph: View {
    let monitor: StorageMonitor

    var body: some View {
        Canvas { ctx, size in
            drawGraph(in: ctx, size: size)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func drawGraph(in ctx: GraphicsContext, size: CGSize) {
        let history = monitor.history
        guard history.count > 1 else { return }

        let peak = monitor.peakBytesPerSec
        let w = size.width
        let h = size.height
        let step = w / CGFloat(monitor.historyCapacity - 1)

        // Grid lines (subtle)
        let gridColor = Color.primary.opacity(0.06)
        for i in 0...3 {
            let y = h * CGFloat(i) / 3.0
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(line, with: .color(gridColor), lineWidth: 0.5)
        }

        // Pad history to historyCapacity points (left-align if still filling)
        let capacity = monitor.historyCapacity
        let padded: [StorageMonitor.Sample]
        if history.count < capacity {
            let zeros = Array(repeating: StorageMonitor.Sample(readBytesPerSec: 0, writeBytesPerSec: 0, temperatureCelsius: nil),
                              count: capacity - history.count)
            padded = zeros + history
        } else {
            padded = Array(history.suffix(capacity))
        }

        // Draw filled area + line for each channel
        drawChannel(padded.map(\.readBytesPerSec),
                    peak: peak, step: step, size: size, color: .blue, in: ctx)
        drawChannel(padded.map(\.writeBytesPerSec),
                    peak: peak, step: step, size: size, color: .orange, in: ctx)

        // Temperature bar across the bottom (3px) if data available
        drawTempStrip(padded, size: size, in: ctx)

        // Axis label: peak value
        let label = Text(formatPeak(peak))
            .font(.system(size: 8).monospaced())
            .foregroundStyle(.secondary)
        ctx.draw(label, at: CGPoint(x: 2, y: 4), anchor: .topLeading)
    }

    private func drawChannel(_ values: [Double],
                              peak: Double,
                              step: CGFloat,
                              size: CGSize,
                              color: Color,
                              in ctx: GraphicsContext) {
        let h = size.height
        var linePath = Path()
        var fillPath = Path()

        for (i, v) in values.enumerated() {
            let x = CGFloat(i) * step
            let y = h - (CGFloat(v / peak) * h).clamped(to: 0...h)
            if i == 0 {
                linePath.move(to: CGPoint(x: x, y: y))
                fillPath.move(to: CGPoint(x: x, y: h))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            } else {
                linePath.addLine(to: CGPoint(x: x, y: y))
                fillPath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Close fill path
        if !values.isEmpty {
            fillPath.addLine(to: CGPoint(x: CGFloat(values.count - 1) * step, y: size.height))
            fillPath.closeSubpath()
        }

        ctx.fill(fillPath, with: .color(color.opacity(0.12)))
        ctx.stroke(linePath, with: .color(color.opacity(0.85)), lineWidth: 1.5)
    }

    /// A 3-pixel-high strip at the very bottom of the graph, colored by temperature over time.
    private func drawTempStrip(_ samples: [StorageMonitor.Sample], size: CGSize, in ctx: GraphicsContext) {
        let hasTempData = samples.contains { $0.temperatureCelsius != nil }
        guard hasTempData else { return }

        let step = size.width / CGFloat(samples.count)
        for (i, sample) in samples.enumerated() {
            guard let temp = sample.temperatureCelsius else { continue }
            let color: Color = temp >= 75 ? .red : temp >= 60 ? .orange : .green
            let x = CGFloat(i) * step
            let rect = CGRect(x: x, y: size.height - 3, width: step, height: 3)
            ctx.fill(Path(rect), with: .color(color.opacity(0.8)))
        }
    }

    private func formatPeak(_ bps: Double) -> String {
        if bps >= 1_073_741_824 { return String(format: "%.0fGB/s", bps / 1_073_741_824) }
        if bps >=     1_048_576 { return String(format: "%.0fMB/s", bps / 1_048_576) }
        return String(format: "%.0fKB/s", bps / 1024)
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
