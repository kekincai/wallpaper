import SwiftUI

struct CachePreferencesView: View {
    @ObservedObject private var store = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("缓存设置")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("最大缓存")
                Slider(value: Binding(
                    get: { Double(store.settings.cacheMaxMB) },
                    set: { store.settings.cacheMaxMB = Int($0) }
                ), in: 256...8192, step: 256)
                Text("\(store.settings.cacheMaxMB) MB")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Toggle("自动清理", isOn: $store.settings.cacheAutoClean)

            HStack {
                Button("立即清理") {
                    CacheManager.shared.cleanIfNeeded(force: true)
                }
                Spacer()
                Button("完成") { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
