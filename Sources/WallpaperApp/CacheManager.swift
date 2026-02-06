import Foundation
import CryptoKit

final class CacheManager {
    static let shared = CacheManager()

    private let fileManager = FileManager.default
    private let settings = SettingsStore.shared

    private lazy var cacheDirectory: URL = {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("WallpaperApp/Cache", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    func cachedURL(for url: URL) -> URL {
        guard isRemote(url: url) else { return url }

        let ext = url.pathExtension
        let name = sha256(url.path) + (ext.isEmpty ? "" : ".\(ext)")
        let dest = cacheDirectory.appendingPathComponent(name)

        if fileManager.fileExists(atPath: dest.path) {
            touch(dest)
            return dest
        }

        do {
            try fileManager.copyItem(at: url, to: dest)
            touch(dest)
            cleanIfNeeded()
            return dest
        } catch {
            return url
        }
    }

    func cleanIfNeeded(force: Bool = false) {
        if !settings.settings.cacheAutoClean && !force { return }
        let maxBytes = Int64(settings.settings.cacheMaxMB) * 1024 * 1024

        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: []) else {
            return
        }

        var entries: [(url: URL, size: Int64, date: Date)] = []
        var total: Int64 = 0
        for file in files {
            let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.contentModificationDate ?? Date.distantPast
            entries.append((file, size, date))
            total += size
        }

        if total <= maxBytes && !force { return }

        let sorted = entries.sorted { $0.date < $1.date }
        var current = total
        for entry in sorted {
            if current <= maxBytes && !force { break }
            try? fileManager.removeItem(at: entry.url)
            current -= entry.size
        }
    }

    private func touch(_ url: URL) {
        let now = Date()
        try? fileManager.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
    }

    private func isRemote(url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey]) else { return false }
        return values.volumeIsLocal == false
    }

    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
