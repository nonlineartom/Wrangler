import Foundation

struct FileEntry: Identifiable, Hashable, Sendable {
    let id: String
    let relativePath: String
    let fileName: String
    let isDirectory: Bool
    let fileSize: Int64
    let modificationDate: Date
    let creationDate: Date?
    let ownerName: String?
    var checksum: String?
    var children: [FileEntry]?

    init(
        relativePath: String,
        fileName: String,
        isDirectory: Bool,
        fileSize: Int64,
        modificationDate: Date,
        creationDate: Date? = nil,
        ownerName: String? = nil,
        checksum: String? = nil,
        children: [FileEntry]? = nil
    ) {
        self.id = relativePath
        self.relativePath = relativePath
        self.fileName = fileName
        self.isDirectory = isDirectory
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.ownerName = ownerName
        self.checksum = checksum
        self.children = children
    }
}

extension FileEntry {
    var isMediaFile: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return Self.mediaExtensions.contains(ext)
    }

    var isVideoFile: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return Self.videoExtensions.contains(ext)
    }

    var isImageFile: Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return Self.imageExtensions.contains(ext)
    }

    static let videoExtensions: Set<String> = [
        "mxf", "mp4", "mov", "avi", "r3d", "braw", "mkv", "wmv", "m4v", "mpg", "mpeg"
    ]

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "tiff", "tif", "cr2", "arw", "dng", "nef", "heic", "heif", "webp"
    ]

    static let mediaExtensions: Set<String> = videoExtensions.union(imageExtensions)
}
