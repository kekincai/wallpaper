import AppKit
import AVFoundation

final class WallpaperView: NSView {
    private var imageLayer: CALayer?
    private var playerLayer: AVPlayerLayer?
    private var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }

    func setImage(url: URL) {
        clearMedia()
        guard let image = NSImage(contentsOf: url) else { return }
        let layer = CALayer()
        layer.frame = bounds
        layer.contentsGravity = .resizeAspectFill
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        self.layer?.addSublayer(layer)
        imageLayer = layer
    }

    func setVideo(url: URL) {
        clearMedia()
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.layer?.addSublayer(layer)
        queuePlayer.play()
        playerLayer = layer
        player = queuePlayer
    }

    func clearMedia() {
        imageLayer?.removeFromSuperlayer()
        imageLayer = nil

        player?.pause()
        player = nil
        playerLooper = nil

        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
}
