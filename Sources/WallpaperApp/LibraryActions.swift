import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension WallpaperItem {
    var isAvailable: Bool { FileManager.default.fileExists(atPath: url.path) }
    var fileName: String { url.lastPathComponent }
}

/// Library mutations shared by the main window, menus and drag-and-drop.
enum LibraryActions {
    static func addFromOpenPanel() {
        let picked = FilePicker.openFilesAndFolders()
        add(urls: FilePicker.collectMediaURLs(from: picked))
    }

    static func add(urls: [URL]) {
        let store = SettingsStore.shared
        var known = Set(store.settings.items.map { $0.url.standardizedFileURL.path })
        var newItems: [WallpaperItem] = []
        for url in urls {
            let path = url.standardizedFileURL.path
            guard !known.contains(path), let kind = kind(for: url) else { continue }
            known.insert(path)
            newItems.append(WallpaperItem(kind: kind, url: url, addedAt: Date()))
        }
        if !newItems.isEmpty {
            store.settings.items.append(contentsOf: newItems)
        }
    }

    static func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        var urls: [URL] = []
        let group = DispatchGroup()
        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                DispatchQueue.main.async {
                    if let url { urls.append(url) }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            add(urls: FilePicker.collectMediaURLs(from: urls))
        }
        return true
    }

    static func remove(id: UUID) {
        SettingsStore.shared.settings.items.removeAll { $0.id == id }
    }

    static func toggleFavorite(id: UUID) {
        let store = SettingsStore.shared
        guard let index = store.settings.items.firstIndex(where: { $0.id == id }) else { return }
        store.settings.items[index].isFavorite.toggle()
    }

    static func revealInFinder(_ item: WallpaperItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private static func kind(for url: URL) -> WallpaperKind? {
        guard FilePicker.isSupportedMedia(url: url) else { return nil }
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            return .image
        }
        return .video
    }
}

/// Rotation interval presets, in minutes. 0 = no rotation.
enum RotationInterval {
    static let presets = [0, 5, 10, 30, 60, 1440]

    static func label(_ minutes: Int) -> String {
        switch minutes {
        case ...0: return "不轮换"
        case 60: return "每小时"
        case 1440: return "每天"
        case let m where m % 60 == 0: return "每 \(m / 60) 小时"
        default: return "每 \(minutes) 分钟"
        }
    }

    /// Presets, plus a stored custom value so the picker never shows blank.
    static func options(including current: Int) -> [Int] {
        presets.contains(current) ? presets : (presets + [current]).sorted()
    }
}

struct IntervalPicker: View {
    let title: String
    @Binding var minutes: Int

    var body: some View {
        Picker(title, selection: $minutes) {
            ForEach(RotationInterval.options(including: minutes), id: \.self) { value in
                Text(RotationInterval.label(value)).tag(value)
            }
        }
    }
}

enum DurationFormat {
    static func string(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Lets non-view code (the app delegate) reopen the library window.
@MainActor
enum WindowRouter {
    static let libraryID = "library"
    static var openLibrary: (() -> Void)?

    static var isLibraryVisible: Bool {
        NSApp.windows.contains { $0.isVisible && $0.identifier?.rawValue.hasPrefix(libraryID) == true }
    }

    static func showLibrary() {
        openLibrary?()
        NSApp.activate()
    }
}
