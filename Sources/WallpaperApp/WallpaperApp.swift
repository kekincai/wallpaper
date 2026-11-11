import SwiftUI

@main
struct WallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store = SettingsStore.shared

    /// SwiftUI writes `isInserted` back during scene updates; only store real changes,
    /// otherwise every write republishes settings and the scene loops.
    private var showMenuBarIcon: Binding<Bool> {
        Binding(
            get: { store.settings.showMenuBarIcon },
            set: { newValue in
                if store.settings.showMenuBarIcon != newValue {
                    store.settings.showMenuBarIcon = newValue
                }
            }
        )
    }

    var body: some Scene {
        Window("壁纸", id: WindowRouter.libraryID) {
            ContentView()
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            AppCommands()
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra("壁纸", systemImage: "photo.on.rectangle", isInserted: showMenuBarIcon) {
            MenuBarPanel()
        }
        .menuBarExtraStyle(.window)
    }
}
