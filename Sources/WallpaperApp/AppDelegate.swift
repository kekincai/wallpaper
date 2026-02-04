import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        WallpaperManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WallpaperManager.shared.stop()
    }
}
