import Foundation
import AppKit
import AVFoundation
import ImageIO

actor ThumbnailEngine {
    private var cache: [String: NSImage] = [:]
    static let thumbnailSize = CGSize(width: 120, height: 80)
    private static let maxConcurrent = 4

    func thumbnail(for url: URL) async -> NSImage? {
        let key = url.path

        if let cached = cache[key] {
            return cached
        }

        let image: NSImage?
        let ext = url.pathExtension.lowercased()

        if FileEntry.videoExtensions.contains(ext) {
            image = await generateVideoThumbnail(url: url)
        } else if FileEntry.imageExtensions.contains(ext) {
            image = generateImageThumbnail(url: url)
        } else {
            image = nil
        }

        if let image {
            cache[key] = image
        }

        return image
    }

    func generateThumbnails(
        for urls: [URL],
        progressHandler: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> [String: NSImage] {
        var results: [String: NSImage] = [:]
        var completed = 0

        await withTaskGroup(of: (String, NSImage?).self) { group in
            var active = 0

            for url in urls {
                if active >= Self.maxConcurrent {
                    if let result = await group.next() {
                        if let image = result.1 {
                            results[result.0] = image
                        }
                        completed += 1
                        active -= 1
                        progressHandler?(completed, urls.count)
                    }
                }

                group.addTask {
                    let image = await self.thumbnail(for: url)
                    return (url.path, image)
                }
                active += 1
            }

            for await result in group {
                if let image = result.1 {
                    results[result.0] = image
                }
                completed += 1
                progressHandler?(completed, urls.count)
            }
        }

        return results
    }

    private func generateVideoThumbnail(url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = Self.thumbnailSize

        let time = CMTime(seconds: 1, preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            return NSImage(cgImage: cgImage, size: Self.thumbnailSize)
        } catch {
            // Try at time 0 if 1s fails
            do {
                let (cgImage, _) = try await generator.image(at: .zero)
                return NSImage(cgImage: cgImage, size: Self.thumbnailSize)
            } catch {
                return nil
            }
        }
    }

    private func generateImageThumbnail(url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(Self.thumbnailSize.width, Self.thumbnailSize.height),
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: Self.thumbnailSize)
    }

    func clearCache() {
        cache.removeAll()
    }
}
