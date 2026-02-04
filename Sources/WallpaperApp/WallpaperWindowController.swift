import AppKit

final class WallpaperWindowController {
    private var screen: NSScreen
    private let window: NSWindow
    private let wallpaperView: WallpaperView

    init(screen: NSScreen) {
        self.screen = screen
        self.wallpaperView = WallpaperView(frame: screen.frame)

        let rect = screen.frame
        self.window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.contentView = wallpaperView
    }

    func show() {
        window.orderFront(nil)
    }

    func hide() {
        window.orderOut(nil)
    }

    func updateScreen(_ screen: NSScreen) {
        self.screen = screen
        let rect = screen.frame
        window.setFrame(rect, display: true)
        wallpaperView.frame = rect
    }

    func updateMedia(item: WallpaperItem?) {
        guard let item else {
            wallpaperView.clearMedia()
            return
        }

        switch item.kind {
        case .image:
            wallpaperView.setImage(url: item.url)
        case .video:
            wallpaperView.setVideo(url: item.url)
        }
    }
}
