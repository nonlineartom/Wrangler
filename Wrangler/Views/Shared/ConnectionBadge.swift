import SwiftUI

/// Compact badge showing drive connection type and a warning for slow connections.
struct ConnectionBadge: View {
    let info: DriveConnectionInfo

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: info.transport.sfSymbol)
                .font(.caption2)
                .foregroundStyle(info.transport.badgeColor)

            Text(info.transport.shortLabel)
                .font(.caption2)
                .foregroundStyle(info.transport.badgeColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(info.transport.badgeColor.opacity(0.12),
                    in: Capsule())
        .help(info.warningMessage ?? info.transport.label)
    }
}
