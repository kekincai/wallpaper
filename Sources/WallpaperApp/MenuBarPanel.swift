import SwiftUI
import AppKit

/// Content of the menu bar extra (window style).
struct MenuBarPanel: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var manager = WallpaperManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = manager.currentItem
        VStack(alignment: .leading, spacing: 10) {
            CurrentWallpaperThumbnail(item: current, cornerRadius: 8)
                .frame(height: 150)

            VStack(alignment: .leading, spacing: 2) {
                Text(current?.fileName ?? "没有壁纸")
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.opacity)
                Text(manager.statusText(includeInterval: true))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 4)
            .animation(Motion.content(reduceMotion: reduceMotion), value: current?.id)
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: manager.statusText(includeInterval: true))

            HStack(spacing: 8) {
                Button(action: manager.togglePause) {
                    PanelTileLabel(title: manager.isPaused ? "继续轮换" : "暂停轮换",
                                   systemImage: manager.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(PanelTileButtonStyle())
                .disabled(current == nil || !manager.canRotate)

                Button(action: manager.advance) {
                    PanelTileLabel(title: "下一张", systemImage: "forward.end.fill")
                }
                .buttonStyle(PanelTileButtonStyle())
                .disabled(current == nil)

                Button { store.settings.shuffle.toggle() } label: {
                    PanelTileLabel(title: "随机", systemImage: "shuffle")
                }
                .buttonStyle(PanelTileButtonStyle(isOn: store.settings.shuffle))
                .accessibilityAddTraits(store.settings.shuffle ? .isSelected : [])
            }
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: manager.isPaused)
            .animation(Motion.feedback(reduceMotion: reduceMotion), value: store.settings.shuffle)

            Divider().padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("更换间隔")
                    Spacer()
                    IntervalPicker(title: "更换间隔", minutes: $store.settings.rotationMinutes)
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                }
                .padding(.horizontal, 8)
                .frame(height: 30)

                Button("打开图库…") {
                    openWindow(id: WindowRouter.libraryID)
                    NSApp.activate()
                }
                .buttonStyle(PanelMenuRowStyle())

                Button {
                    openSettings()
                    NSApp.activate()
                } label: {
                    Text("设置…")
                    Spacer()
                    Text("⌘,").foregroundStyle(.secondary)
                }
                .buttonStyle(PanelMenuRowStyle())
                .keyboardShortcut(",", modifiers: .command)
            }

            Divider().padding(.horizontal, 4)

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出壁纸")
                Spacer()
                Text("⌘Q").foregroundStyle(.secondary)
            }
            .buttonStyle(PanelMenuRowStyle())
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(12)
        .frame(width: 320)
        .symbolEffectsRemoved(reduceMotion)
    }
}

private struct PanelTileLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(.caption)
        }
    }
}

private struct PanelTileButtonStyle: ButtonStyle {
    var isOn = false

    func makeBody(configuration: Configuration) -> some View {
        TileBody(configuration: configuration, isOn: isOn)
    }

    private struct TileBody: View {
        let configuration: Configuration
        let isOn: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .fontWeight(isOn ? .semibold : .regular)
                .foregroundStyle(isOn ? Color(nsColor: .alternateSelectedControlTextColor) : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.45)
        }
    }
}

/// A full-width row that highlights like a menu item on hover.
private struct PanelMenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        let configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            HStack(spacing: 8) {
                configuration.label
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .foregroundStyle(isHovered ? Color(nsColor: .alternateSelectedControlTextColor) : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor : .clear)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
        }
    }
}
