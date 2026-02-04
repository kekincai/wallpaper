import Foundation

enum WallpaperKind: String, Codable {
    case image
    case video
}

struct WallpaperItem: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: WallpaperKind
    var url: URL
    var isFavorite: Bool
    var addedAt: Date

    init(kind: WallpaperKind, url: URL, id: UUID = UUID(), isFavorite: Bool = false, addedAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.url = url
        self.isFavorite = isFavorite
        self.addedAt = addedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(WallpaperKind.self, forKey: .kind)
        url = try container.decode(URL.self, forKey: .url)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
    }
}
