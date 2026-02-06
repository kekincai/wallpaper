import Foundation

struct AppSettings: Codable, Equatable {
    var items: [WallpaperItem]
    var rotationMinutes: Int
    var shuffle: Bool
    var launchAtLogin: Bool
    var cacheMaxMB: Int
    var cacheAutoClean: Bool

    static let `default` = AppSettings(
        items: [],
        rotationMinutes: 10,
        shuffle: true,
        launchAtLogin: false,
        cacheMaxMB: 2048,
        cacheAutoClean: true
    )

    init(items: [WallpaperItem], rotationMinutes: Int, shuffle: Bool, launchAtLogin: Bool, cacheMaxMB: Int, cacheAutoClean: Bool) {
        self.items = items
        self.rotationMinutes = rotationMinutes
        self.shuffle = shuffle
        self.launchAtLogin = launchAtLogin
        self.cacheMaxMB = cacheMaxMB
        self.cacheAutoClean = cacheAutoClean
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([WallpaperItem].self, forKey: .items) ?? []
        rotationMinutes = try container.decodeIfPresent(Int.self, forKey: .rotationMinutes) ?? 10
        shuffle = try container.decodeIfPresent(Bool.self, forKey: .shuffle) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        cacheMaxMB = try container.decodeIfPresent(Int.self, forKey: .cacheMaxMB) ?? 2048
        cacheAutoClean = try container.decodeIfPresent(Bool.self, forKey: .cacheAutoClean) ?? true
    }
}

final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { save() }
    }

    static let shared = SettingsStore()

    private let key = "WallpaperApp.Settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? decoder.decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }

    private func save() {
        if let data = try? encoder.encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
