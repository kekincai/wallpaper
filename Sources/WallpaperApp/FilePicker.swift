import AppKit
import UniformTypeIdentifiers

enum FilePicker {
    static func openFilesAndFolders() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .movie, .folder]
        if panel.runModal() == .OK {
            return panel.urls
        }
        return []
    }

    static func collectMediaURLs(from urls: [URL]) -> [URL] {
        var results: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        if isSupportedMedia(url: fileURL) {
                            results.append(fileURL)
                        }
                    }
                }
            } else {
                if isSupportedMedia(url: url) {
                    results.append(url)
                }
            }
        }
        return results
    }

    static func isSupportedMedia(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie)
    }
}
