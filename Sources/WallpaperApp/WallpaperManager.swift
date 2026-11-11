import AppKit
import Combine

@MainActor
final class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    /// The library item currently shown on the desktop.
    @Published private(set) var currentItemID: UUID?
    /// Rotation is paused (manually, or because a wallpaper was picked by hand).
    @Published private(set) var isPaused = false

    private var windows: [UInt32: WallpaperWindowController] = [:]
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var currentResolved: WallpaperItem?
    private var started = false

    private let settingsStore = SettingsStore.shared

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - State

    var currentItem: WallpaperItem? {
        guard let currentItemID else { return nil }
        return settingsStore.settings.items.first { $0.id == currentItemID }
    }

    /// Rotation can run at all (an interval is set).
    var canRotate: Bool { settingsStore.settings.rotationMinutes > 0 }

    /// e.g. "轮换中 · 随机顺序", "已暂停 · 每 10 分钟 · 顺序播放"
    func statusText(includeInterval: Bool = false) -> String {
        let settings = settingsStore.settings
        guard currentItem != nil else {
            return settings.items.isEmpty ? "图库为空" : "没有可用的壁纸"
        }
        var parts: [String] = []
        if !canRotate {
            parts.append("不轮换")
        } else {
            parts.append(isPaused ? "已暂停" : "轮换中")
            if includeInterval { parts.append(RotationInterval.label(settings.rotationMinutes)) }
        }
        parts.append(settings.shuffle ? "随机顺序" : "顺序播放")
        return parts.joined(separator: " · ")
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        rebuildWindows()
        show(pickNext())
        scheduleTimer()
        observeSettings()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        windows.values.forEach { $0.hide() }
        windows.removeAll()
    }

    // MARK: - Controls

    /// Show the next wallpaper. Keeps the current paused/rotating state.
    func advance() {
        show(pickNext())
        scheduleTimer()
    }

    func pause() {
        isPaused = true
        scheduleTimer()
    }

    func resume() {
        isPaused = false
        scheduleTimer()
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    /// Show a specific wallpaper. Picking one by hand pauses rotation.
    func setWallpaper(id: UUID) {
        guard let item = settingsStore.settings.items.first(where: { $0.id == id }),
              item.isAvailable else { return }
        show(item)
        pause()
    }

    // MARK: - Private

    private func observeSettings() {
        // @Published emits in willSet, so hop to the next main-queue turn to read the new value.
        settingsStore.$settings
            .map(\.rotationMinutes)
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleTimer() }
            .store(in: &cancellables)

        settingsStore.$settings
            .map { $0.items.map(\.id) }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.libraryChanged() }
            .store(in: &cancellables)
    }

    /// Items were added or removed: only switch if the current wallpaper is gone (or nothing is showing).
    private func libraryChanged() {
        if let item = currentItem, item.isAvailable { return }
        show(pickNext())
    }

    @objc private func handleScreenChange() {
        rebuildWindows()
    }

    private func rebuildWindows() {
        var next: [UInt32: WallpaperWindowController] = [:]

        for screen in NSScreen.screens {
            let id = screenID(screen)
            if let existing = windows[id] {
                existing.updateScreen(screen)
                next[id] = existing
            } else {
                let controller = WallpaperWindowController(screen: screen)
                controller.show()
                controller.updateMedia(item: currentResolved)
                next[id] = controller
            }
        }

        for id in Set(windows.keys).subtracting(next.keys) {
            windows[id]?.hide()
        }

        windows = next
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil

        let minutes = settingsStore.settings.rotationMinutes
        guard !isPaused, minutes > 0 else { return }

        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advance()
            }
        }
    }

    private func pickNext() -> WallpaperItem? {
        let items = settingsStore.settings.items.filter(\.isAvailable)
        guard !items.isEmpty else { return nil }

        if settingsStore.settings.shuffle {
            let pool = items.count > 1 ? items.filter { $0.id != currentItemID } : items
            return pool.randomElement()
        }

        if let currentItemID, let index = items.firstIndex(where: { $0.id == currentItemID }) {
            return items[(index + 1) % items.count]
        }
        return items.first
    }

    private func show(_ item: WallpaperItem?) {
        currentItemID = item?.id
        currentResolved = item.map(resolveItem)
        windows.values.forEach { $0.updateMedia(item: currentResolved) }
    }

    private func resolveItem(_ item: WallpaperItem) -> WallpaperItem {
        guard item.kind == .video else { return item }
        let cached = CacheManager.shared.cachedURL(for: item.url)
        if cached == item.url { return item }
        var copy = item
        copy.url = cached
        return copy
    }

    private func screenID(_ screen: NSScreen) -> UInt32 {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.uint32Value
        }
        return UInt32(truncatingIfNeeded: ObjectIdentifier(screen).hashValue)
    }
}
