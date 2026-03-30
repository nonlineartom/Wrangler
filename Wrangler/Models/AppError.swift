import Foundation

struct CopyError: Identifiable, Sendable {
    let id = UUID()
    let relativePath: String
    let message: String
    let isRetryable: Bool
    let timestamp: Date

    init(relativePath: String, message: String, isRetryable: Bool = true) {
        self.relativePath = relativePath
        self.message = message
        self.isRetryable = isRetryable
        self.timestamp = .now
    }
}

enum WranglerError: LocalizedError {
    case sourceNotAccessible(URL)
    case destinationNotAccessible(URL)
    case insufficientSpace(required: Int64, available: Int64)
    case checksumMismatch(file: String, expected: String, actual: String)
    case copyFailed(file: String, underlying: Error)
    case scanFailed(underlying: Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .sourceNotAccessible(let url):
            "Cannot access source: \(url.path)"
        case .destinationNotAccessible(let url):
            "Cannot access destination: \(url.path)"
        case .insufficientSpace(let required, let available):
            "Insufficient space: need \(ByteCountFormatting.string(fromByteCount: required)), have \(ByteCountFormatting.string(fromByteCount: available))"
        case .checksumMismatch(let file, _, _):
            "Checksum mismatch for \(file)"
        case .copyFailed(let file, let error):
            "Copy failed for \(file): \(error.localizedDescription)"
        case .scanFailed(let error):
            "Scan failed: \(error.localizedDescription)"
        case .cancelled:
            "Operation cancelled"
        }
    }
}
