import AppKit
import Combine

@MainActor
final class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()

    private var windows: [UInt32: WallpaperWindowController] = [:]
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var currentIndex: Int = 0
    private var manualOverrideID: UUID?

    private let settingsStore = SettingsStore.shared

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func start() {
        rebuildWindows()
        applyCurrentItem()
        scheduleTimer()
        observeSettings()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        windows.values.forEach { $0.hide() }
        windows.removeAll()
    }

    private func observeSettings() {
        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.scheduleTimer()
                self.applyCurrentItem(resetIndex: true)
            }
            .store(in: &cancellables)
    }

    @objc private func handleScreenChange() {
        rebuildWindows()
        applyCurrentItem()
    }

    private func rebuildWindows() {
        let screens = NSScreen.screens
        var next: [UInt32: WallpaperWindowController] = [:]

        for screen in screens {
            let id = screenID(screen)
            if let existing = windows[id] {
                existing.updateScreen(screen)
                next[id] = existing
            } else {
                let controller = WallpaperWindowController(screen: screen)
                controller.show()
                next[id] = controller
            }
        }

        let removed = Set(windows.keys).subtracting(next.keys)
        for id in removed {
            windows[id]?.hide()
        }

        windows = next
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil

        if manualOverrideID != nil {
            return
        }

        let minutes = settingsStore.settings.rotationMinutes
        if minutes <= 0 { return }

        let clamped = max(1, minutes)
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(clamped * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advance()
            }
        }
    }

    func advance() {
        manualOverrideID = nil
        applyCurrentItem()
        scheduleTimer()
    }

    private func applyCurrentItem(resetIndex: Bool = false) {
        let items = settingsStore.settings.items.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        guard !items.isEmpty else {
            windows.values.forEach { $0.updateMedia(item: nil) }
            return
        }

        if resetIndex {
            currentIndex = 0
        }

        let nextItem: WallpaperItem
        if let manualID = manualOverrideID,
           let manualItem = items.first(where: { $0.id == manualID }) {
            nextItem = manualItem
        } else {
            if settingsStore.settings.shuffle {
                nextItem = items.randomElement() ?? items[0]
            } else {
                if currentIndex >= items.count { currentIndex = 0 }
                nextItem = items[currentIndex]
                currentIndex += 1
            }
        }

        let resolved = resolveItem(nextItem)
        windows.values.forEach { $0.updateMedia(item: resolved) }
        if manualOverrideID == nil {
            scheduleTimer()
        }
    }

    func setManualItem(id: UUID?) {
        manualOverrideID = id
        applyCurrentItem()
        if id == nil {
            scheduleTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
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
