import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
            RotationSettingsView()
                .tabItem { Label("轮换", systemImage: "arrow.triangle.2.circlepath") }
            CacheSettingsView()
                .tabItem { Label("缓存", systemImage: "internaldrive") }
        }
        .frame(width: 520)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                Toggle("登录时打开", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { enabled in
                        LoginItemManager.setEnabled(enabled)
                        store.settings.launchAtLogin = LoginItemManager.isEnabled
                    }
                ))
                Toggle("在菜单栏中显示", isOn: $store.settings.showMenuBarIcon)
            } footer: {
                SettingsFooter("关闭主窗口后，壁纸会继续在后台轮换；可以从菜单栏图标重新打开图库。")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 150)
    }
}

private struct RotationSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        Form {
            Section {
                IntervalPicker(title: "更换壁纸", minutes: $store.settings.rotationMinutes)
                Toggle("随机顺序", isOn: $store.settings.shuffle)
            } footer: {
                SettingsFooter("手动指定某张壁纸后轮换会暂停，可在图库或菜单栏中恢复。")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 150)
    }
}

private struct CacheSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @State private var confirmClean = false
    @State private var usedBytes: Int64 = 0

    var body: some View {
        Form {
            Section {
                LabeledContent("最大缓存") {
                    HStack(spacing: 8) {
                        Text("256 MB").font(.caption).foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(store.settings.cacheMaxMB) },
                                // Snap to 256 MB manually: `step:` would draw 31 tick marks.
                                set: { store.settings.cacheMaxMB = Int(($0 / 256).rounded()) * 256 }
                            ),
                            in: 256...8192,
                            onEditingChanged: { editing in
                                if !editing { cleanIfNeeded() }
                            }
                        )
                        .labelsHidden()
                        .frame(width: 160)
                        Text("8 GB").font(.caption).foregroundStyle(.secondary)
                        Text(Self.sizeLabel(store.settings.cacheMaxMB))
                            .monospacedDigit()
                            .frame(minWidth: 56, alignment: .trailing)
                    }
                }
                Toggle("超过上限时自动清理", isOn: $store.settings.cacheAutoClean)
                    .onChange(of: store.settings.cacheAutoClean) { _, _ in cleanIfNeeded() }
                LabeledContent {
                    Button("立即清理…") { confirmClean = true }
                } label: {
                    Text("清除所有缓存")
                    Text("已使用 \(ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file))")
                }
            } footer: {
                SettingsFooter("清理缓存不会删除图库中的壁纸文件。")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(height: 205)
        .onAppear(perform: refreshUsage)
        .confirmationDialog("清除所有缓存？", isPresented: $confirmClean) {
            Button("清理", role: .destructive) {
                CacheManager.shared.cleanIfNeeded(force: true)
                refreshUsage()
            }
        } message: {
            Text("网络卷上的视频会在下次使用时重新缓存。图库中的壁纸文件不受影响。")
        }
    }

    private func cleanIfNeeded() {
        CacheManager.shared.cleanIfNeeded()
        refreshUsage()
    }

    private func refreshUsage() {
        usedBytes = CacheManager.shared.currentSize()
    }

    static func sizeLabel(_ mb: Int) -> String {
        guard mb >= 1024 else { return "\(mb) MB" }
        let gb = Double(mb) / 1024
        return gb == gb.rounded() ? "\(Int(gb)) GB" : String(format: "%.2g GB", gb)
    }
}

private struct SettingsFooter: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
