import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case favorites = "收藏"
    case images = "图片"
    case videos = "视频"

    var id: String { rawValue }

    func matches(_ item: WallpaperItem) -> Bool {
        switch self {
        case .all: return true
        case .favorites: return item.isFavorite
        case .images: return item.kind == .image
        case .videos: return item.kind == .video
        }
    }
}

struct ContentView: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var manager = WallpaperManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filter: LibraryFilter = .all
    @State private var searchText = ""
    @State private var selectedID: UUID?
    @State private var isDropTargeted = false
    @FocusState private var gridFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 184), spacing: 16)]

    private var isLibraryEmpty: Bool { store.settings.items.isEmpty }

    private var visibleItems: [WallpaperItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return store.settings.items.filter { item in
            filter.matches(item) && (query.isEmpty || item.fileName.localizedCaseInsensitiveContains(query))
        }
    }

    private var subtitle: String {
        isLibraryEmpty ? "无项目" : "\(visibleItems.count) 项"
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLibraryEmpty {
                EmptyLibraryView(isTargeted: isDropTargeted)
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    CurrentWallpaperBar()
                    Divider()
                    gridArea
                }
                .transition(.opacity)
            }
        }
        .background(.background)
        .animation(Motion.content(reduceMotion: reduceMotion), value: isLibraryEmpty)
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        .symbolEffectsRemoved(reduceMotion)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: LibraryActions.handleDrop)
        .navigationTitle("壁纸")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("筛选", selection: $filter) {
                    ForEach(LibraryFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            // Flexible space: keeps ＋ beside the search field instead of against the filter.
            ToolbarItem(placement: .automatic) {
                Spacer()
            }
            ToolbarItem(placement: .automatic) {
                Button(action: LibraryActions.addFromOpenPanel) {
                    Label("添加壁纸", systemImage: "plus")
                }
                .help("添加图片或视频（⌘O）")
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "搜索")
        .frame(minWidth: 720, minHeight: 480)
        .onAppear {
            WindowRouter.openLibrary = { [openWindow] in openWindow(id: WindowRouter.libraryID) }
        }
    }

    // MARK: Grid

    @ViewBuilder
    private var gridArea: some View {
        let items = visibleItems
        ZStack {
            if items.isEmpty {
                noResultsView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            } else {
                grid(items)
                    .transition(.opacity)
            }
        }
        .animation(Motion.content(reduceMotion: reduceMotion), value: items.isEmpty)
    }

    private func grid(_ items: [WallpaperItem]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(items) { item in
                    tile(for: item)
                        .transition(.pop(reduceMotion: reduceMotion))
                }
            }
            .padding(20)
            // Filtering, searching, adding and removing reflow the grid instead of jumping.
            .animation(Motion.content(reduceMotion: reduceMotion), value: items.map(\.id))
        }
        .focusable()
        .focused($gridFocused)
        .focusEffectDisabled()
        .onKeyPress(.return) { activateSelection() }
        .onKeyPress(.delete) { removeSelection() }
        .onKeyPress(.deleteForward) { removeSelection() }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(6)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var noResultsView: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            switch filter {
            case .favorites:
                ContentUnavailableView("没有收藏的壁纸", systemImage: "heart",
                                       description: Text("在壁纸上右键选择“收藏”。"))
            case .images:
                ContentUnavailableView("没有图片", systemImage: "photo")
            case .videos:
                ContentUnavailableView("没有视频", systemImage: "film")
            case .all:
                EmptyView()
            }
        }
    }

    private func tile(for item: WallpaperItem) -> some View {
        let available = item.isAvailable
        return LibraryTile(
            item: item,
            isSelected: selectedID == item.id,
            isCurrent: manager.currentItemID == item.id,
            isAvailable: available
        )
        .onTapGesture(count: 2) { setWallpaper(item) }
        .simultaneousGesture(TapGesture().onEnded { select(item) })
        .accessibilityAction { select(item) }
        .accessibilityAction(named: "设为壁纸") { setWallpaper(item) }
        .accessibilityAction(named: item.isFavorite ? "取消收藏" : "收藏") { LibraryActions.toggleFavorite(id: item.id) }
        .accessibilityAction(named: "从图库移除") { remove(item.id) }
        .contextMenu {
            Button("设为壁纸") { setWallpaper(item) }
                .disabled(!available)
            Button(item.isFavorite ? "取消收藏" : "收藏") { LibraryActions.toggleFavorite(id: item.id) }
            Button("在访达中显示") { LibraryActions.revealInFinder(item) }
                .disabled(!available)
            Divider()
            Button("从图库移除") { remove(item.id) }
        }
    }

    // MARK: Actions

    private func select(_ item: WallpaperItem) {
        selectedID = item.id
        gridFocused = true
    }

    private func setWallpaper(_ item: WallpaperItem) {
        guard item.isAvailable else { return }
        selectedID = item.id
        manager.setWallpaper(id: item.id)
    }

    private func remove(_ id: UUID) {
        if selectedID == id { selectedID = nil }
        LibraryActions.remove(id: id)
    }

    private func activateSelection() -> KeyPress.Result {
        guard let selectedID, let item = visibleItems.first(where: { $0.id == selectedID }) else { return .ignored }
        setWallpaper(item)
        return .handled
    }

    private func removeSelection() -> KeyPress.Result {
        guard let selectedID else { return .ignored }
        remove(selectedID)
        return .handled
    }
}

// MARK: - Current wallpaper bar

private struct CurrentWallpaperBar: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var manager = WallpaperManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = manager.currentItem
        HStack(spacing: 14) {
            CurrentWallpaperThumbnail(item: current)
                .frame(width: 104, height: 65)

            VStack(alignment: .leading, spacing: 2) {
                Text("当前壁纸")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(current?.fileName ?? "无")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.opacity)
                Text(manager.statusText())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .animation(Motion.content(reduceMotion: reduceMotion), value: current?.id)
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: manager.statusText())

            Spacer(minLength: 12)

            ControlGroup {
                Button(action: manager.togglePause) {
                    Label {
                        Text(manager.isPaused ? "继续轮换" : "暂停轮换")
                    } icon: {
                        Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .help(manager.isPaused ? "继续轮换" : "暂停轮换")
                .disabled(!manager.canRotate)

                Button(action: manager.advance) {
                    Label("下一张", systemImage: "forward.end.fill")
                }
                .help("下一张")
            }
            .labelStyle(.iconOnly)
            .fixedSize()
            .disabled(current == nil)
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: manager.isPaused)

            Toggle(isOn: $store.settings.shuffle) {
                Label("随机顺序", systemImage: "shuffle")
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .help("随机顺序")

            IntervalPicker(title: "更换", minutes: $store.settings.rotationMinutes)
                .fixedSize()
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

// MARK: - Tile

private struct LibraryTile: View {
    let item: WallpaperItem
    let isSelected: Bool
    let isCurrent: Bool
    let isAvailable: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var duration: Double?

    init(item: WallpaperItem, isSelected: Bool, isCurrent: Bool, isAvailable: Bool) {
        self.item = item
        self.isSelected = isSelected
        self.isCurrent = isCurrent
        self.isAvailable = isAvailable
        _duration = State(initialValue: ThumbnailProvider.shared.cachedDuration(for: item.url))
    }

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
            caption
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .task(id: item.url) {
            guard item.kind == .video, isAvailable, duration == nil else { return }
            duration = await ThumbnailProvider.shared.duration(for: item.url)
        }
    }

    private var thumbnail: some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay {
                if isAvailable {
                    MediaThumbnail(url: item.url)
                } else {
                    missingPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: isAvailable ? 0.5 : 1)
            )
            .overlay(alignment: .bottomLeading) {
                if isCurrent {
                    TileBadge { Text("正在使用") }
                        .padding(8)
                        .transition(.pop(reduceMotion: reduceMotion, from: 0.8))
                }
            }
            .overlay(alignment: .topTrailing) {
                if item.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .padding(8)
                        .transition(.pop(reduceMotion: reduceMotion, from: 0.5))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if item.kind == .video, isAvailable, let duration {
                    TileBadge {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill").font(.system(size: 7))
                            Text(DurationFormat.string(duration)).monospacedDigit()
                        }
                    }
                    .padding(8)
                    .transition(.opacity)
                }
            }
            .overlay {
                if isSelected {
                    // Settles onto the thumbnail from slightly outside.
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .padding(-5)
                        .transition(.pop(reduceMotion: reduceMotion, from: 1.06))
                }
            }
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: isSelected)
            .animation(Motion.content(reduceMotion: reduceMotion), value: isCurrent)
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: item.isFavorite)
            .animation(.easeOut(duration: 0.2), value: duration)
    }

    private var missingPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                    Text("找不到文件")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
    }

    private var caption: some View {
        Text(item.fileName)
            .font(.system(size: 12))
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(captionColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .transition(.opacity)
                }
            }
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: isSelected)
            .frame(maxWidth: .infinity)
    }

    private var captionColor: Color {
        if isSelected { return Color(nsColor: .alternateSelectedControlTextColor) }
        return isAvailable ? .primary : .secondary
    }

    private var accessibilityText: String {
        var parts = [item.fileName]
        if isCurrent { parts.append("正在使用") }
        if item.isFavorite { parts.append("已收藏") }
        if item.kind == .video, let duration { parts.append("视频 \(DurationFormat.string(duration))") }
        if !isAvailable { parts.append("找不到文件") }
        return parts.joined(separator: "，")
    }
}

/// Small label drawn over a thumbnail; always dark so it reads on any image.
private struct TileBadge<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Empty state

private struct EmptyLibraryView: View {
    let isTargeted: Bool
    /// Bumped when a drag enters, so the icon acknowledges it once.
    @State private var dragEnterCount = 0

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(isTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .symbolEffect(.bounce, value: dragEnterCount)
            Text("还没有壁纸")
                .font(.title2.bold())
                .padding(.top, 6)
            Text("把图片、视频或整个文件夹拖到这里，或者从磁盘中选择。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("选择文件…", action: LibraryActions.addFromOpenPanel)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 10)
            Text("快捷键 ⌘O")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(isTargeted ? 0.12 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(isTargeted ? 1 : 0.7),
                              style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        )
        .padding(20)
        .onChange(of: isTargeted) { _, targeted in
            if targeted { dragEnterCount += 1 }
        }
    }
}

#Preview {
    ContentView()
}
