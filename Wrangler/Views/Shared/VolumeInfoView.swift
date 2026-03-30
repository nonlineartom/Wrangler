import SwiftUI

struct VolumeInfoView: View {
    let volumeInfo: VolumeInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: volumeInfo.typeIcon)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(volumeInfo.name)
                    .font(.caption)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text(volumeInfo.typeLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("\(ByteCountFormatting.string(fromByteCount: volumeInfo.availableCapacity)) free")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            CapacityBarView(usage: volumeInfo.usagePercent)
                .frame(width: 60, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct CapacityBarView: View {
    let usage: Double

    var barColor: Color {
        if usage > 0.9 { return .red }
        if usage > 0.75 { return .orange }
        return .accentColor
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: max(0, geo.size.width * usage))
            }
        }
    }
}
