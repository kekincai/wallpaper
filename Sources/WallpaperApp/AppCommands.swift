import SwiftUI
import UniformTypeIdentifiers

struct AppCommands: Commands {
    @ObservedObject private var store = SettingsStore.shared

    var body: some Commands {
        MenuPruningCommands()

        CommandMenu("播放") {
            Button("下一张") { WallpaperManager.shared.advance() }
                .keyboardShortcut("n", modifiers: [.command])
            Button("恢复轮换") { WallpaperManager.shared.setManualItem(id: nil) }
        }

        CommandMenu("素材") {
            Button("添加素材…") {
                let picked = FilePicker.openFilesAndFolders()
                let urls = FilePicker.collectMediaURLs(from: picked)
                let existing = Set(store.settings.items.map { $0.url.path })
                let newItems: [WallpaperItem] = urls.compactMap { url in
                    guard !existing.contains(url.path) else { return nil }
                    guard FilePicker.isSupportedMedia(url: url) else { return nil }
                    let isImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
                    let kind: WallpaperKind = isImage ? .image : .video
                    return WallpaperItem(kind: kind, url: url)
                }
                if !newItems.isEmpty {
                    store.settings.items.append(contentsOf: newItems)
                }
            }
        }

        CommandMenu("偏好") {
            Toggle("随机播放", isOn: $store.settings.shuffle)
            Toggle("开机自启", isOn: $store.settings.launchAtLogin)
            Divider()
            Button("缓存设置…") {
                NotificationCenter.default.post(name: .openPreferences, object: nil)
            }
        }
    }
}

private struct MenuPruningCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) { }
        CommandGroup(replacing: .help) { }
        CommandGroup(replacing: .windowList) { }
        CommandGroup(replacing: .toolbar) { }
        CommandGroup(replacing: .undoRedo) { }
        CommandGroup(replacing: .sidebar) { }
        CommandGroup(replacing: .windowSize) { }
        CommandGroup(replacing: .textEditing) { }
    }
}
