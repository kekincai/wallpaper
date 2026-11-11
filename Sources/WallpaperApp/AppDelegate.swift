import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        SettingsStore.shared.settings.launchAtLogin = LoginItemManager.isEnabled
        CacheManager.shared.cleanIfNeeded()
        WallpaperManager.shared.start()
    }

    /// Closing the library window keeps the app (and rotation) running in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// The desktop wallpaper windows always count as "visible", so reopen the library ourselves on Dock click.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated {
            if !WindowRouter.isLibraryVisible {
                WindowRouter.showLibrary()
            }
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            WallpaperManager.shared.stop()
        }
    }
}
