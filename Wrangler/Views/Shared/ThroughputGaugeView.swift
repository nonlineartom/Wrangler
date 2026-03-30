import SwiftUI

struct ThroughputGaugeView: View {
    let bytesPerSecond: Double
    let eta: TimeInterval?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Throughput")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(ByteCountFormatting.throughputString(bytesPerSecond: bytesPerSecond))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            if let eta {
                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(ByteCountFormatting.durationString(from: eta))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
