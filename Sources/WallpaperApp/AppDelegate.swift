import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        CacheManager.shared.cleanIfNeeded()
        WallpaperManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WallpaperManager.shared.stop()
    }
}
