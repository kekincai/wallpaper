import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum LibrarySection: String, CaseIterable, Identifiable {
    case library = "图库"
    case favorites = "精选集"
    case personal = "个人收藏"
    case recentAdded = "最近追加"
    case videos = "视频"

    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var selectedID: UUID?
    @State private var hoveredID: UUID?
    @State private var isDropTargeted = false
    @State private var selection: LibrarySection = .library
    @State private var showControls = true
    @State private var scrollDebounce: DispatchWorkItem?

    private let columns = [
        GridItem(.adaptive(minimum: 170), spacing: 16)
    ]

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            ZStack {
                Color.black.opacity(0.92).ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Divider().opacity(0.12)
                    gridArea
                }
            }
            .navigationTitle(selection.rawValue)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        Button("添加素材") {
                            addItemsFromPanel()
                        }
                        Button("下一张") {
                            WallpaperManager.shared.advance()
                        }
                        Button("恢复轮换") {
                            selectedID = nil
                            WallpaperManager.shared.setManualItem(id: nil)
                        }
                    }
                }
            }
        }
        .onAppear {
            store.settings.launchAtLogin = LoginItemManager.isEnabled
        }
        .onChange(of: store.settings.launchAtLogin) { _, newValue in
            if newValue != LoginItemManager.isEnabled {
                LoginItemManager.setEnabled(newValue)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }

    private var topBar: some View {
        HStack {
            Text(selection.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            HStack(spacing: 8) {
                Chip(text: store.settings.rotationMinutes == 0 ? "不轮换" : "\(store.settings.rotationMinutes) 分钟")
                Chip(text: "素材 \(store.settings.items.count)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.35))
    }

    private var gridArea: some View {
        ScrollView {
            if filteredItems.isEmpty {
                EmptyStateView()
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .padding(.top, 40)
            } else {
                ScrollOffsetReader()
                    .frame(height: 0)
                    .onPreferenceChange(ScrollOffsetKey.self) { _ in
                        handleScroll()
                    }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredItems) { item in
                        PhotoTile(
                            item: item,
                            isSelected: selectedID == item.id,
                            isHovered: hoveredID == item.id,
                            onSelect: { selectItem(item) },
                            onDelete: { removeItem(item) },
                            onToggleFavorite: { toggleFavorite(item) }
                        )
                        .onHover { hovering in
                            hoveredID = hovering ? item.id : nil
                        }
                        .contextMenu {
                            Button("设为当前") { selectItem(item) }
                            Button(item.isFavorite ? "取消精选" : "加入精选") { toggleFavorite(item) }
                            Button("删除") { removeItem(item) }
                        }
                    }
                }
                .padding(18)
            }
        }
        .coordinateSpace(name: "scroll")
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDropTargeted ? Color.blue.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(12)
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .overlay(alignment: .bottomLeading) {
            if showControls {
                controlBar
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            Button("移除选中") { removeSelection() }
                .disabled(selectedID == nil)
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.18))
            Button("清空") { store.settings.items.removeAll() }
                .disabled(store.settings.items.isEmpty)
                .buttonStyle(.bordered)
            Toggle("随机播放", isOn: $store.settings.shuffle)
                .toggleStyle(.switch)
                .foregroundStyle(.white.opacity(0.8))
            Toggle("开机自启", isOn: $store.settings.launchAtLogin)
                .toggleStyle(.switch)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var filteredItems: [WallpaperItem] {
        let items = store.settings.items
        switch selection {
        case .library:
            return items
        case .favorites:
            return items.filter { $0.isFavorite }
        case .personal:
            return items.filter { $0.isFavorite }
        case .recentAdded:
            return items.sorted(by: { $0.addedAt > $1.addedAt })
        case .videos:
            return items.filter { $0.kind == .video }
        }
    }

    private func addItemsFromPanel() {
        let picked = FilePicker.openFilesAndFolders()
        let urls = FilePicker.collectMediaURLs(from: picked)
        addItems(urls: urls)
    }

    private func addItems(urls: [URL]) {
        let existing = Set(store.settings.items.map { $0.url.path })
        let newItems: [WallpaperItem] = urls.compactMap { url in
            guard !existing.contains(url.path) else { return nil }
            guard let kind = inferKind(url: url) else { return nil }
            return WallpaperItem(kind: kind, url: url, addedAt: Date())
        }

        if !newItems.isEmpty {
            store.settings.items.append(contentsOf: newItems)
        }
    }

    private func removeSelection() {
        guard let selectedID else { return }
        store.settings.items.removeAll { $0.id == selectedID }
        self.selectedID = nil
        WallpaperManager.shared.setManualItem(id: nil)
    }

    private func removeItem(_ item: WallpaperItem) {
        store.settings.items.removeAll { $0.id == item.id }
        if selectedID == item.id {
            selectedID = nil
            WallpaperManager.shared.setManualItem(id: nil)
        }
    }

    private func selectItem(_ item: WallpaperItem) {
        selectedID = item.id
        WallpaperManager.shared.setManualItem(id: item.id)
    }

    private func toggleFavorite(_ item: WallpaperItem) {
        guard let index = store.settings.items.firstIndex(where: { $0.id == item.id }) else { return }
        store.settings.items[index].isFavorite.toggle()
    }

    private func inferKind(url: URL) -> WallpaperKind? {
        guard FilePicker.isSupportedMedia(url: url) else { return nil }
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            return .image
        }
        return .video
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            let expanded = FilePicker.collectMediaURLs(from: urls)
            addItems(urls: expanded)
        }

        return true
    }

    private func handleScroll() {
        if showControls {
            withAnimation(.easeInOut(duration: 0.15)) {
                showControls = false
            }
        }

        scrollDebounce?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = true
            }
        }
        scrollDebounce = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: workItem)
    }
}

private struct SidebarView: View {
    @Binding var selection: LibrarySection

    var body: some View {
        List(selection: $selection) {
            Section("图库") {
                SidebarRow(title: "图库", systemImage: "photo.on.rectangle", section: .library)
                SidebarRow(title: "精选集", systemImage: "star", section: .favorites)
            }

            Section("固定") {
                SidebarRow(title: "个人收藏", systemImage: "heart", section: .personal)
                SidebarRow(title: "最近追加", systemImage: "clock.arrow.circlepath", section: .recentAdded)
                SidebarRow(title: "视频", systemImage: "play.rectangle", section: .videos)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("图库")
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let section: LibrarySection

    var body: some View {
        Label(title, systemImage: systemImage)
            .tag(section)
    }
}

private struct Chip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08), in: Capsule())
            .foregroundStyle(.white.opacity(0.8))
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.6))
            Text("拖拽图片或视频到这里")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text("支持文件夹导入与批量添加")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}

private struct PhotoTile: View {
    let item: WallpaperItem
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                Image(nsImage: ThumbnailProvider.shared.thumbnail(for: item.url, size: CGSize(width: 220, height: 150)))
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(10)

                HStack {
                    Button(action: onToggleFavorite) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(item.isFavorite ? Color.yellow : Color.white.opacity(0.8))
                            .padding(6)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)

                    Spacer()

                    if item.kind == .video {
                        Text("0:06")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(6)
                    }
                }
            }

            Text(item.url.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isSelected ? 0.18 : (isHovered ? 0.12 : 0.06)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onTapGesture { onSelect() }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named("scroll")).minY)
        }
    }
}

#Preview {
    ContentView()
}
