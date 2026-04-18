import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager
    @ObservedObject var store: PromptStore
    @ObservedObject var hotKeyManager = HotKeyManager.shared
    @State private var showingStats = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    Text("主题：")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .trailing)

                    Picker("", selection: $theme.mode) {
                        ForEach(ThemeMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Text("数据新增：")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .trailing)

                    Picker("", selection: $theme.dataAddPosition) {
                        ForEach(DataAddPosition.allCases) { position in
                            Text(position.displayName).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .controlSize(.small)
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Text("快捷图标：")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("悬停展开最近提示语", isOn: $theme.quickAccessEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)

                        if theme.quickAccessEnabled {
                            HStack(spacing: 6) {
                                Text("显示条数")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                Picker("", selection: $theme.quickAccessItemCount) {
                                    ForEach(ThemeManager.itemCountOptions, id: \.self) { count in
                                        Text("\(count) 条").tag(count)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 70)
                                .controlSize(.small)
                            }

                            HStack(spacing: 6) {
                                Text("每列条数")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                Picker("", selection: $theme.quickAccessItemsPerColumn) {
                                    ForEach(ThemeManager.itemsPerColumnOptions, id: \.self) { count in
                                        Text("\(count) 条").tag(count)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 70)
                                .controlSize(.small)
                            }

                            HStack(spacing: 6) {
                                Text("自动收起")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                Picker("", selection: $theme.quickAccessDismissDelay) {
                                    ForEach(ThemeManager.dismissDelayOptions, id: \.self) { sec in
                                        Text("\(sec, specifier: "%.1f") 秒").tag(sec)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 70)
                                .controlSize(.small)
                            }

                            HStack(spacing: 6) {
                                Text("显示分类")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                Picker("", selection: $theme.quickAccessCategoryId) {
                                    Text("全部").tag(nil as UUID?)
                                    ForEach(store.categories) { category in
                                        Label(category.name, systemImage: category.icon)
                                            .tag(Optional(category.id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 100)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Text("全局快捷键：")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("启用全局快捷键", isOn: $theme.globalHotKeyEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: theme.globalHotKeyEnabled) { enabled in
                                // 先更新缓存，确保 EventTap 读取到最新配置
                                HotKeyManager.shared.updateCache()
                                if enabled || theme.promptInputHotKeyEnabled {
                                    HotKeyManager.shared.start()
                                } else {
                                    HotKeyManager.shared.stop()
                                }
                            }

                        if theme.globalHotKeyEnabled {
                            HStack(spacing: 6) {
                                Text("呼出快捷键")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                HotKeyRecorderView()
                            }

                            HStack(spacing: 6) {
                                Text("辅助功能")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                if hotKeyManager.isAccessibilityGranted {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("已授权")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                        Text("需要授权")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)

                                        Button("去授权") {
                                            hotKeyManager.openAccessibilitySettings()
                                        }
                                        .controlSize(.small)
                                    }
                                }
                            }

                            Text("快捷键可在任意应用中呼出悬浮图标")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Text("输入快捷键：")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("启用提示语输入快捷键", isOn: $theme.promptInputHotKeyEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .onChange(of: theme.promptInputHotKeyEnabled) { enabled in
                                HotKeyManager.shared.updateCache()
                                if enabled || theme.globalHotKeyEnabled {
                                    HotKeyManager.shared.start()
                                } else {
                                    HotKeyManager.shared.stop()
                                }
                            }

                        if theme.promptInputHotKeyEnabled {
                            HStack(spacing: 6) {
                                Text("快捷键")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)

                                PromptInputHotKeyRecorderView()
                            }

                            Text("快捷键可在任意应用中呼出提示语输入框")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Text("数据统计：")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .trailing)

                    Button {
                        showingStats = true
                    } label: {
                        Label("查看提示语统计", systemImage: "chart.bar.xaxis")
                    }
                    .controlSize(.small)
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Text("开发调试：")
                        .font(.system(size: 13))
                        .frame(width: 70, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("启用 Debug 模式", isOn: $theme.debugModeEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)

                        if theme.debugModeEnabled {
                            Text("AI 服务详细日志已启用")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                            
                            HStack(spacing: 4) {
                                Text("日志路径:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    let logPath = AILogger.shared.logFilePath
                                    NSWorkspace.shared.selectFile(logPath, inFileViewerRootedAtPath: "")
                                } label: {
                                    Text("在 Finder 中显示")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.link)
                            }
                        } else {
                            Text("关闭时不记录 AI 服务日志")
                                .font(.system(size: 11))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
            .padding(30)
            .frame(width: 340)
            .sheet(isPresented: $showingStats) {
                PromptStatsView(store: store)
            }

            Spacer()
                .frame(height: 2)

            Text("power by weibo_chaohua@wangchen12")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)
        }
        .onAppear {
            _ = hotKeyManager.checkAccessibilityPermission()
            if theme.globalHotKeyEnabled || theme.promptInputHotKeyEnabled {
                hotKeyManager.start()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            _ = hotKeyManager.checkAccessibilityPermission()
            if theme.globalHotKeyEnabled || theme.promptInputHotKeyEnabled {
                hotKeyManager.start()
            }
        }
    }
}
