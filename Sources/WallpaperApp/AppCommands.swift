import SwiftUI

struct AppCommands: Commands {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var manager = WallpaperManager.shared

    var body: some Commands {
        // File menu: there is nothing to create, only to import.
        CommandGroup(replacing: .newItem) {
            Button("添加壁纸…", action: LibraryActions.addFromOpenPanel)
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("播放") {
            Button("下一张", action: manager.advance)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(store.settings.items.isEmpty)
            Button(manager.isPaused ? "继续轮换" : "暂停轮换", action: manager.togglePause)
                .disabled(manager.currentItemID == nil || store.settings.rotationMinutes == 0)
        }
    }
}
