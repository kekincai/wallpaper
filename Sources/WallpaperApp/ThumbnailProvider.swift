import AppKit
import AVFoundation
import ImageIO
import SwiftUI

/// Downsampled thumbnails and video durations, loaded off the main thread and cached.
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let images = NSCache<NSString, NSImage>()
    private let durations = NSCache<NSURL, NSNumber>()

    private func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(url.path)#\(maxPixel)" as NSString
    }

    func cachedThumbnail(for url: URL, maxPixel: Int) -> NSImage? {
        images.object(forKey: key(url, maxPixel))
    }

    func thumbnail(for url: URL, maxPixel: Int) async -> NSImage? {
        if let cached = cachedThumbnail(for: url, maxPixel: maxPixel) { return cached }
        let image = await Task.detached(priority: .utility) { () async -> NSImage? in
            if let image = Self.imageThumbnail(url: url, maxPixel: maxPixel) { return image }
            return await Self.videoThumbnail(url: url, maxPixel: maxPixel)
        }.value
        if let image { images.setObject(image, forKey: key(url, maxPixel)) }
        return image
    }

    func cachedDuration(for url: URL) -> Double? {
        durations.object(forKey: url as NSURL)?.doubleValue
    }

    func duration(for url: URL) async -> Double? {
        if let cached = cachedDuration(for: url) { return cached }
        guard let time = try? await AVURLAsset(url: url).load(.duration) else { return nil }
        let seconds = time.seconds
        guard seconds.isFinite, seconds > 0 else { return nil }
        durations.setObject(NSNumber(value: seconds), forKey: url as NSURL)
        return seconds
    }

    private static func imageThumbnail(url: URL, maxPixel: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    private static func videoThumbnail(url: URL, maxPixel: Int) async -> NSImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        guard let (cg, _) = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)) else {
            return nil
        }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

/// Aspect-fill thumbnail for a media file; fills its frame, caller clips.
struct MediaThumbnail: View {
    let url: URL
    var maxPixel: Int = 480
    @State private var image: NSImage?

    init(url: URL, maxPixel: Int = 480) {
        self.url = url
        self.maxPixel = maxPixel
        _image = State(initialValue: ThumbnailProvider.shared.cachedThumbnail(for: url, maxPixel: maxPixel))
    }

    var body: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            // Async loads fade in; cached thumbnails are set in init and appear immediately.
            .animation(.easeOut(duration: 0.2), value: image != nil)
            .task(id: url) {
                image = await ThumbnailProvider.shared.thumbnail(for: url, maxPixel: maxPixel)
            }
    }
}

/// Thumbnail of the wallpaper that is currently on the desktop (or a placeholder).
struct CurrentWallpaperThumbnail: View {
    let item: WallpaperItem?
    var cornerRadius: CGFloat = 6

    var body: some View {
        // Crossfade (never movement) when the wallpaper changes, so it is fine under Reduce Motion too.
        ZStack {
            Group {
                if let item, item.isAvailable {
                    MediaThumbnail(url: item.url)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .id(item?.id)
            .transition(.opacity)
        }
        .animation(.smooth(duration: 0.4), value: item?.id)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }
}
