import AppKit
import AVFoundation

final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let cache = NSCache<NSURL, NSImage>()

    func thumbnail(for url: URL, size: CGSize) -> NSImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let image: NSImage
        if let nsImage = NSImage(contentsOf: url) {
            image = nsImage
        } else {
            image = generateVideoThumbnail(url: url) ?? NSImage()
        }

        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    private func generateVideoThumbnail(url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.0, preferredTimescale: 600)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            let image = NSImage(cgImage: cgImage, size: size)
            return image
        }
        return nil
    }
}
