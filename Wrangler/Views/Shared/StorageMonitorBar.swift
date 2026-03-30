import SwiftUI

// MARK: - iStat-style storage monitor bar

struct StorageMonitorBar: View {
    @State private var monitor = StorageMonitor.shared
    @State private var volumes: [VolumeInfo] = []

    // iStat signature colours
    private let readColor  = Color(red: 1.00, green: 0.18, blue: 0.33)  // hot pink
    private let writeColor = Color(red: 0.04, green: 0.52, blue: 1.00)  // electric blue
    private let bgColor    = Color(red: 0.09, green: 0.13, blue: 0.19)
    private let labelColor = Color(red: 0.40, green: 0.82, blue: 1.00)  // iStat cyan

    var body: some View {
        HStack(spacing: 0) {
            // ── Left: bar chart + labels ──────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                // Section title
                Text("DISK ACTIVITY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(labelColor)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                // Bidirectional bar chart
                BidirectionalBarChart(
                    monitor: monitor,
                    readColor: readColor,
                    writeColor: writeColor
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                // Speed legend
                HStack(spacing: 16) {
                    speedLabel(dot: readColor,  label: "Read",  rate: monitor.current.readBytesPerSec)
                    speedLabel(dot: writeColor, label: "Write", rate: monitor.current.writeBytesPerSec)
                    if let temp = monitor.current.temperatureCelsius {
                        Spacer()
                        tempBadge(celsius: temp)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .frame(minWidth: 320)

            // Separator
            Rectangle()
                .fill(.white.opacity(0.07))
                .frame(width: 1)

            // ── Right: mounted volume chips ───────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(volumes) { vol in
                        VolumeChip(vol: vol, accentColor: labelColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(height: 88)
        .background(bgColor)
        .onAppear { volumes = VolumeDetector.mountedVolumes() }
    }

    // MARK: - Sub-views

    private func speedLabel(dot: Color, label: String, rate: Double) -> some View {
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            Text(formatRate(rate))
                .font(.system(size: 10, weight: .semibold).monospaced())
                .foregroundStyle(.white)
        }
    }

    private func tempBadge(celsius: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "thermometer.medium")
                .font(.system(size: 9))
                .foregroundStyle(tempColor(celsius))
            Text(String(format: "%.0f°C", celsius))
                .font(.system(size: 10).monospaced())
                .foregroundStyle(tempColor(celsius))
        }
    }

    // MARK: - Helpers

    private func formatRate(_ bps: Double) -> String {
        if bps >= 1_073_741_824 { return String(format: "%.1f GB/s", bps / 1_073_741_824) }
        if bps >=     1_048_576 { return String(format: "%.1f MB/s", bps / 1_048_576) }
        if bps >=          1024 { return String(format: "%.0f KB/s", bps / 1024) }
        return "0 KB/s"
    }

    private func tempColor(_ c: Double) -> Color {
        c >= 75 ? .red : c >= 60 ? .orange : .green
    }
}

// MARK: - Bidirectional bar chart (read up / write down)

private struct BidirectionalBarChart: View {
    let monitor: StorageMonitor
    let readColor: Color
    let writeColor: Color

    var body: some View {
        Canvas { ctx, size in
            let samples = monitor.history
            guard !samples.isEmpty else { return }

            let peak     = max(monitor.peakBytesPerSec, 1.0)
            let centerY  = size.height / 2
            let maxBarH  = centerY - 1
            let n        = CGFloat(samples.count)
            let barW     = size.width / n
            let gap      = barW > 3 ? CGFloat(1) : CGFloat(0.5)

            for (i, s) in samples.enumerated() {
                let x = CGFloat(i) * barW

                // Read — up from centre (pink)
                let rh = CGFloat(s.readBytesPerSec / peak) * maxBarH
                if rh > 0.5 {
                    ctx.fill(
                        Path(CGRect(x: x, y: centerY - rh, width: max(barW - gap, 1), height: rh)),
                        with: .color(readColor)
                    )
                }

                // Write — down from centre (blue)
                let wh = CGFloat(s.writeBytesPerSec / peak) * maxBarH
                if wh > 0.5 {
                    ctx.fill(
                        Path(CGRect(x: x, y: centerY, width: max(barW - gap, 1), height: wh)),
                        with: .color(writeColor)
                    )
                }
            }

            // Centre axis line
            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: centerY))
            axis.addLine(to: CGPoint(x: size.width, y: centerY))
            ctx.stroke(axis, with: .color(.white.opacity(0.12)), lineWidth: 0.5)

            // Peak label (top-left corner)
            let peakLabel = formatPeak(peak)
            ctx.draw(
                Text(peakLabel)
                    .font(.system(size: 8).monospaced())
                    .foregroundStyle(Color.white.opacity(0.3)),
                at: CGPoint(x: 2, y: 2),
                anchor: .topLeading
            )
        }
    }

    private func formatPeak(_ bps: Double) -> String {
        if bps >= 1_073_741_824 { return String(format: "%.0fGB/s", bps / 1_073_741_824) }
        if bps >=     1_048_576 { return String(format: "%.0fMB/s", bps / 1_048_576) }
        return String(format: "%.0fKB/s", bps / 1024)
    }
}

// MARK: - Volume chip

private struct VolumeChip: View {
    let vol: VolumeInfo
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            // Circular usage ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: min(CGFloat(vol.usagePercent), 1))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(vol.usagePercent * 100))")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)

            // Name + free space
            VStack(alignment: .leading, spacing: 2) {
                Text(vol.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(ByteCountFormatting.string(fromByteCount: vol.availableCapacity)) free")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .frame(minWidth: 140)
    }

    private var ringColor: Color {
        let p = vol.usagePercent
        if p > 0.90 { return .red }
        if p > 0.75 { return .orange }
        return accentColor
    }
}
